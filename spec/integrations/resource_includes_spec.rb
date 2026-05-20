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
      relationship :parts, preload: :raw_parts do |_, parts|
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

        relationship :owner, preload: :raw_owner do |_, owner|
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
end
