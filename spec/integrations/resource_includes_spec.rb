# frozen_string_literal: true

RSpec.describe "ResourceIncludes integration" do
  # A minimal child serializer used to render each part.
  #
  let(:part_serializer_class) do
    Class.new do
      include Halitosis

      resource :part

      attribute(:label) { part.to_s }

      # These relationships must be declared so that include=parts.detail and
      # include=parts.summary pass validate_relationships! on the child.
      relationship(:detail) { nil }
      relationship(:summary) { nil }
    end
  end

  # The parent serializer with a preloaded collection relationship and
  # allow_include declarations for two nested paths.
  #
  let(:serializer_class) do
    part_class = part_serializer_class

    Class.new do
      include Halitosis

      resource :record

      # Returns a plain array of strings that simulate a collection.
      # The allow_include procs transform this array before the relationship
      # renders, proving the cache is modified.
      #
      relationship :parts, preload: :raw_parts do |parts|
        (parts || []).map { |p| part_class.new(p) }
      end

      allow_include :parts do
        allow_include(:detail) { |parts| parts.map { |p| "#{p}:detail" } }
        allow_include(:summary) { |parts| parts.map { |p| "#{p}:summary" } }
      end

      def raw_parts
        %w[alpha beta]
      end
    end
  end

  let(:record_resource) { Struct.new(:id).new(1) }

  def render(serializer, include:)
    serializer.new(record_resource, include: include).render
  end

  def parts_from(result)
    result.dig(:record, :_relationships, :parts)
  end

  describe "when no nested include path is requested" do
    it "renders parts without any transformation" do
      result = render(serializer_class, include: "parts")

      labels = parts_from(result).map { |p| p[:label] }

      expect(labels).to eq(%w[alpha beta])
    end
  end

  describe "when include=parts.detail is requested" do
    it "applies the :detail procedure before rendering" do
      result = render(serializer_class, include: "parts.detail")

      labels = parts_from(result).map { |p| p[:label] }

      expect(labels).to eq(["alpha:detail", "beta:detail"])
    end
  end

  describe "when include=parts.summary is requested" do
    it "applies the :summary procedure before rendering" do
      result = render(serializer_class, include: "parts.summary")

      labels = parts_from(result).map { |p| p[:label] }

      expect(labels).to eq(["alpha:summary", "beta:summary"])
    end
  end

  describe "when multiple nested paths are requested" do
    it "applies both procedures in sequence to the same cache entry" do
      result = render(serializer_class, include: "parts.detail,parts.summary")

      # :detail runs first (transforms alpha/beta → alpha:detail/beta:detail),
      # then :summary runs on the already-transformed values.
      labels = parts_from(result).map { |p| p[:label] }

      expect(labels).to eq(["alpha:detail:summary", "beta:detail:summary"])
    end
  end

  describe "with a singular (non-array) relationship" do
    let(:owner_serializer_class) do
      Class.new do
        include Halitosis

        resource :owner

        attribute(:name) { owner.to_s }

        relationship(:detail) { nil }
      end
    end

    let(:singular_serializer_class) do
      owner_class = owner_serializer_class

      Class.new do
        include Halitosis

        resource :record

        relationship :owner, preload: :raw_owner do |owner|
          owner_class.new(owner)
        end

        allow_include :owner do
          allow_include(:detail) { |owner| "#{owner}:detail" }
        end

        def raw_owner
          "bob"
        end
      end
    end

    def owner_from(result)
      result.dig(:record, :_relationships, :owner)
    end

    describe "when no nested include path is requested" do
      it "renders the owner without transformation" do
        result = render(singular_serializer_class, include: "owner")

        expect(owner_from(result)[:name]).to eq("bob")
      end
    end

    describe "when include=owner.detail is requested" do
      it "applies the :detail procedure before rendering" do
        result = render(singular_serializer_class, include: "owner.detail")

        expect(owner_from(result)[:name]).to eq("bob:detail")
      end
    end
  end

  describe "allow_include without a block (no procedure)" do
    # Regression: bare `allow_include :parts` (no block) used to default to
    # DEFAULT_PROCEDURE, causing apply_include_procedure to run unnecessarily
    # and raise ArgumentError when a preload was registered for that key.
    #
    let(:no_block_serializer_class) do
      part_class = part_serializer_class

      Class.new do
        include Halitosis

        resource :record

        relationship :parts, preload: :raw_parts do |parts|
          (parts || []).map { |p| part_class.new(p) }
        end

        allow_include :parts

        def raw_parts
          %w[alpha beta]
        end
      end
    end

    it "renders without raising an error" do
      result = render(no_block_serializer_class, include: "parts")

      labels = parts_from(result).map { |p| p[:label] }
      expect(labels).to eq(%w[alpha beta])
    end
  end

  describe "allow_include with a procedure when the relationship is gated by if:" do
    # Regression: when a relationship has an `if:` condition that is not satisfied,
    # its preload is never populated. The allow_include enhancer should silently
    # skip rather than raising ArgumentError.
    #
    let(:gated_serializer_class) do
      part_class = part_serializer_class

      Class.new do
        include Halitosis

        resource :record

        relationship :parts, if: :parts_enabled?, preload: :raw_parts do |parts|
          (parts || []).map { |p| part_class.new(p) }
        end

        allow_include :parts do |parts|
          parts.map { |p| "#{p}:enhanced" }
        end

        def raw_parts
          %w[alpha beta]
        end

        def parts_enabled?
          options.fetch(:parts_enabled, true)
        end
      end
    end

    it "renders without raising when the gated relationship is disabled" do
      serializer = gated_serializer_class.new(record_resource, include: "parts", parts_enabled: false)

      expect { serializer.render }.not_to raise_error
    end

    it "applies the procedure when the relationship is enabled" do
      result = render(gated_serializer_class, include: "parts")

      labels = parts_from(result).map { |p| p[:label] }
      expect(labels).to eq(["alpha:enhanced", "beta:enhanced"])
    end
  end

  describe "enforce_allow_include!" do
    let(:child_class) do
      Class.new do
        include Halitosis

        resource :part

        attribute(:label) { part.to_s }

        relationship(:detail) { nil }
      end
    end

    let(:enforced_class) do
      part_class = child_class

      Class.new do
        include Halitosis

        resource :record

        enforce_allow_include!

        relationship :parts, preload: :raw_parts do |parts|
          (parts || []).map { |p| part_class.new(p) }
        end

        relationship(:secret) { nil }

        allow_include :parts do
          allow_include(:detail) { |parts| parts.map { |p| "#{p}:detail" } }
        end

        def raw_parts
          %w[alpha beta]
        end
      end
    end

    it "renders a relationship that has a matching allow_include" do
      result = render(enforced_class, include: "parts")

      labels = parts_from(result).map { |p| p[:label] }
      expect(labels).to eq(%w[alpha beta])
    end

    it "renders a nested path that has a matching allow_include" do
      result = render(enforced_class, include: "parts.detail")

      labels = parts_from(result).map { |p| p[:label] }
      expect(labels).to eq(["alpha:detail", "beta:detail"])
    end

    it "raises for a relationship without a matching allow_include" do
      expect {
        render(enforced_class, include: "secret")
      }.to raise_error(
        Halitosis::InvalidIncludeParameter,
        /does not have a `secret` relationship path/
      )
    end

    it "raises for a nested path without a matching allow_include" do
      expect {
        render(enforced_class, include: "parts.summary")
      }.to raise_error(
        Halitosis::InvalidIncludeParameter,
        /does not have a `parts.summary` relationship path/
      )
    end

    it "raises for an entirely unknown include path" do
      expect {
        render(enforced_class, include: "bogus")
      }.to raise_error(
        Halitosis::InvalidIncludeParameter,
        /does not have a `bogus` relationship path/
      )
    end

    it "does not raise when no include is requested" do
      expect { render(enforced_class, include: nil) }.not_to raise_error
    end

    context "when no allow_include is declared at all" do
      let(:no_allow_class) do
        Class.new do
          include Halitosis

          resource :record

          enforce_allow_include!

          relationship(:parts) { nil }
        end
      end

      it "raises when any include is requested" do
        expect {
          no_allow_class.new(record_resource, include: "parts").render
        }.to raise_error(
          Halitosis::InvalidIncludeParameter,
          /does not have a `parts` relationship path/
        )
      end

      it "does not raise when no include is requested" do
        expect { no_allow_class.new(record_resource).render }.not_to raise_error
      end
    end

    it "is inherited by subclasses" do
      subclass = Class.new(enforced_class)

      expect(subclass.enforce_allow_include?).to be(true)
      expect {
        subclass.new(record_resource, include: "secret").render
      }.to raise_error(Halitosis::InvalidIncludeParameter)
    end

    it "is not enabled by default" do
      unenforced = Class.new do
        include Halitosis

        resource :record

        relationship(:secret) { nil }
      end

      expect(unenforced.enforce_allow_include?).to be(false)
      expect { unenforced.new(record_resource, include: "secret").render }.not_to raise_error
    end
  end

  describe "top-level allow_include builder with a preload" do
    # Regression: the arity-0 (builder) branch of ClassMethods#allow_include
    # was hard-coding nil as the procedure, silently discarding any preload
    # declared inside the builder block.
    #
    let(:builder_preload_serializer_class) do
      part_class = part_serializer_class

      Class.new do
        include Halitosis

        resource :record

        relationship :parts, preload: :raw_parts do |parts|
          (parts || []).map { |p| part_class.new(p) }
        end

        allow_include :parts do
          preload ->(parts) { parts.map { |p| "#{p}:loaded" } }

          allow_include(:detail) { |parts| parts.map { |p| "#{p}:detail" } }
        end

        def raw_parts
          %w[alpha beta]
        end
      end
    end

    describe "when only the top-level path is requested (include=parts)" do
      it "applies the top-level builder preload" do
        result = render(builder_preload_serializer_class, include: "parts")

        labels = parts_from(result).map { |p| p[:label] }

        expect(labels).to eq(["alpha:loaded", "beta:loaded"])
      end
    end

    describe "when a nested path is requested (include=parts.detail)" do
      it "applies both the top-level builder preload and the nested child preload" do
        result = render(builder_preload_serializer_class, include: "parts.detail")

        labels = parts_from(result).map { |p| p[:label] }

        # top-level preload runs first (:loaded), then :detail procedure runs
        expect(labels).to eq(["alpha:loaded:detail", "beta:loaded:detail"])
      end
    end
  end
end
