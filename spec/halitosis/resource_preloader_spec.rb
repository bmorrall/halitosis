# frozen_string_literal: true

RSpec.describe Halitosis::ResourcePreloader do
  let :klass do
    Class.new do
      include Halitosis::Base
      include Halitosis::Preloadable
      include Halitosis::ResourceRelationships
      include Halitosis::ResourceIncludes
    end
  end

  describe Halitosis::ResourcePreloader::InstanceMethods do
    describe "#process_resource_includes" do
      it "does nothing when no matching allow_include fields are registered" do
        klass.relationship(:accounts) { |v| v }
        # no allow_include registered

        serializer = klass.new(include: {accounts: true})
        context = serializer.send(:build_context)

        # Prime the preload cache so the path would fire if a field existed
        serializer.send(:store_preload, context, :accounts, [:data])

        expect { serializer.send(:process_resource_includes, context) }.not_to raise_error
      end

      it "raises ArgumentError when no preload value is cached" do
        klass.relationship(:accounts) { |v| v }
        klass.allow_include(:accounts) { |v| v }

        serializer = klass.new(include: "accounts")
        context = serializer.send(:build_context)

        expect { serializer.send(:process_resource_includes, context) }.to raise_error(
          ArgumentError,
          /allow_include :accounts.*not been preloaded/
        )
      end

      it "applies the allow_include procedure when preloaded and field is present" do
        klass.relationship(:accounts) { |v| v }

        transformed = nil
        klass.allow_include(:accounts) { |v| transformed = v.map { |x| x * 2 } }

        serializer = klass.new(include: "accounts")
        context = serializer.send(:build_context)
        serializer.send(:store_preload, context, :accounts, [1, 2, 3])

        serializer.send(:process_resource_includes, context)

        expect(serializer.send(:fetch_preload, context, :accounts)).to eq([2, 4, 6])
        expect(transformed).to eq([2, 4, 6])
      end

      it "traverses the include tree for nested paths" do
        klass.relationship(:accounts) { |v| v }

        fired = []
        klass.allow_include(:accounts) do
          allow_include(:owner) { |v|
            fired << :owner
            v
          }
        end

        serializer = klass.new(include: "accounts.owner")
        context = serializer.send(:build_context)
        serializer.send(:store_preload, context, :accounts, [:some_data])

        serializer.send(:process_resource_includes, context)

        expect(fired).to eq([:owner])
      end

      it "does not fire when the preloaded value is nil" do
        received = :unset

        klass.relationship(:accounts) { |v| v }
        klass.allow_include(:accounts) { |v| received = v }

        serializer = klass.new(include: "accounts")
        context = serializer.send(:build_context)
        serializer.send(:store_preload, context, :accounts, nil)

        expect { serializer.send(:process_resource_includes, context) }.not_to raise_error
        expect(received).to eq(:unset)
      end
    end
  end

  describe Halitosis::ResourcePreloader::ClassMethods do
    let :klass do
      Class.new do
        include Halitosis::Base
        include Halitosis::Preloadable
        include Halitosis::ResourceRelationships
      end
    end

    describe ".preload" do
      it "registers a ResourcePreloader::Field with the given name" do
        klass.preload(:violations)

        field = klass.fields.find_by_name(Halitosis::ResourcePreloader::Field, :violations)

        expect(field).to be_a(Halitosis::ResourcePreloader::Field)
        expect(field.name).to eq(:violations)
        expect(field.key).to eq(:violations)
      end

      it "uses the :as option as the cache key and field name" do
        klass.preload(:flight_violations, as: :violations)

        field = klass.fields.find_by_name(Halitosis::ResourcePreloader::Field, :violations)

        expect(field).not_to be_nil
        expect(field.key).to eq(:flight_violations)
      end

      it "is idempotent — calling twice does not register a second field" do
        klass.preload(:violations)
        klass.preload(:violations)

        fields = klass.fields.for_type(Halitosis::ResourcePreloader::Field)

        expect(fields.size).to eq(1)
      end

      it "returns nil" do
        expect(klass.preload(:violations)).to be_nil
      end
    end

    describe "relationship :name, preload: ..." do
      it "registers a preloader field for an arity-1 block (auto-inferred)" do
        klass.relationship(:violations) { |vals| vals }

        field = klass.fields.find_by_name(Halitosis::ResourcePreloader::Field, :violations)

        expect(field).not_to be_nil
        expect(field.key).to eq(:violations)
      end

      it "registers a preloader field with a custom key for preload: :flight_violations" do
        klass.relationship(:violations, preload: :flight_violations) { |vals| vals }

        field = klass.fields.find_by_name(Halitosis::ResourcePreloader::Field, :violations)

        expect(field).not_to be_nil
        expect(field.key).to eq(:flight_violations)
      end

      it "does not register a preloader field when preload: false" do
        klass.relationship(:violations, preload: false) { |vals| vals }

        field = klass.fields.find_by_name(Halitosis::ResourcePreloader::Field, :violations)

        expect(field).to be_nil
      end

      it "does not register a preloader field for an arity-0 block without explicit preload:" do
        klass.relationship(:violations) { nil }

        field = klass.fields.find_by_name(Halitosis::ResourcePreloader::Field, :violations)

        expect(field).to be_nil
      end

      it "registers a preloader field when preload: true is explicit and block is arity 0" do
        klass.relationship(:violations, preload: true) { nil }

        field = klass.fields.find_by_name(Halitosis::ResourcePreloader::Field, :violations)

        expect(field).not_to be_nil
        expect(field.key).to eq(:violations)
      end

      it "does not register a second preloader field when both preload: and standalone preload are called" do
        klass.preload(:violations)
        klass.relationship(:violations) { |vals| vals }

        fields = klass.fields.for_type(Halitosis::ResourcePreloader::Field)

        expect(fields.size).to eq(1)
      end
    end
  end

  describe "#preload_value" do
    let :klass do
      Class.new do
        include Halitosis::Base
        include Halitosis::Preloadable
        include Halitosis::ResourceRelationships

        def violations
          [:v1, :v2]
        end
      end
    end

    it "stores the result of the source method under the cache key" do
      klass.preload(:violations)

      serializer = klass.new
      context = serializer.send(:build_context)

      serializer.send(:preload_value, context, :violations)

      expect(serializer.send(:fetch_preload, context, :violations)).to eq([:v1, :v2])
    end

    it "evaluates a shared source key only once across multiple calls" do
      call_count = 0

      klass.define_method(:shared_source) do
        call_count += 1
        [:data]
      end

      klass.preload(:shared_source, as: :rel_a)
      klass.preload(:shared_source, as: :rel_b)

      serializer = klass.new
      context = serializer.send(:build_context)

      serializer.send(:preload_value, context, :rel_a)
      serializer.send(:preload_value, context, :rel_b)

      expect(call_count).to eq(1)
    end

    it "stores the same value under both relationship cache keys when source is shared" do
      klass.define_method(:shared_source) { [:shared] }

      klass.preload(:shared_source, as: :rel_a)
      klass.preload(:shared_source, as: :rel_b)

      serializer = klass.new
      context = serializer.send(:build_context)

      serializer.send(:preload_value, context, :rel_a)
      serializer.send(:preload_value, context, :rel_b)

      expect(serializer.send(:fetch_preload, context, :rel_a)).to eq([:shared])
      expect(serializer.send(:fetch_preload, context, :rel_b)).to eq([:shared])
    end
  end
end
