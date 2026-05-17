# frozen_string_literal: true

RSpec.describe Halitosis::CollectionFilterable do
  let :klass do
    Class.new do
      include Halitosis

      collection :items do |collection|
        collection
      end

      filterable_by :name do |collection, value|
        collection.select { |i| i[:name] == value }
      end

      filterable_by :score do |collection, value|
        integer_value = Integer(value)
        collection.select { |i| i[:score] == integer_value }
      rescue ArgumentError, TypeError
        nil
      end
    end
  end

  let(:items) do
    [
      {name: "Alice", score: 1},
      {name: "Bob", score: 2},
      {name: "Alice", score: 3}
    ]
  end

  describe ".filterable_by" do
    it "adds a Filterable::Field to the class fields" do
      fields = klass.fields.for_type(Halitosis::CollectionFilterable::Field)

      expect(fields.size).to eq(2)
      expect(fields.map(&:name)).to contain_exactly(:name, :score)
    end

    it "raises InvalidField without a block" do
      expect do
        klass.filterable_by(:title)
      end.to raise_error(Halitosis::InvalidField, /filter field title must be defined with a proc/i)
    end

    it "raises InvalidField when the block accepts more than 2 arguments" do
      expect do
        klass.filterable_by(:title) { |a, b, c| a }
      end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*or 2 arguments/i)
    end

    context "with a zero-arity namespace block" do
      it "registers nested fields with dot-prefixed names" do
        ns_klass = Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          filterable_by :user do
            filterable_by :name do |collection, value|
              collection.select { |i| i[:name] == value }
            end
          end
        end

        fields = ns_klass.fields.for_type(Halitosis::CollectionFilterable::Field)
        expect(fields.size).to eq(1)
        expect(fields.first.name).to eq(:"user.name")
      end

      it "supports multiple levels of nesting" do
        ns_klass = Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          filterable_by :a do
            filterable_by :b do
              filterable_by :c do |collection, value|
                collection.select { |i| i[:c] == value }
              end
            end
          end
        end

        fields = ns_klass.fields.for_type(Halitosis::CollectionFilterable::Field)
        expect(fields.size).to eq(1)
        expect(fields.first.name).to eq(:"a.b.c")
      end

      it "supports multiple fields inside a single namespace" do
        ns_klass = Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          filterable_by :user do
            filterable_by :name do |collection, v|
              collection.select { |i| i[:name] == v }
            end

            filterable_by :age do |collection, v|
              collection.select { |i| i[:age] == v.to_i }
            end
          end
        end

        fields = ns_klass.fields.for_type(Halitosis::CollectionFilterable::Field)
        expect(fields.map(&:name)).to contain_exactly(:"user.name", :"user.age")
      end

      it "raises InvalidField when a nested block accepts more than 2 arguments" do
        expect do
          Class.new do
            include Halitosis

            collection :items do |collection|
              collection
            end

            filterable_by :user do
              filterable_by :name do |a, b, c|
                a
              end
            end
          end
        end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*or 2 arguments/i)
      end
    end
  end

  describe "#validate_filters!" do
    let(:serializer) { klass.new(items) }

    it "passes when all requested keys are declared" do
      expect do
        serializer.send(:validate_filters!, [["name", "Alice"]])
      end.not_to raise_error
    end

    it "passes for multiple known keys" do
      expect do
        serializer.send(:validate_filters!, [["name", "Alice"], ["score", "1"]])
      end.not_to raise_error
    end

    it "raises InvalidFilterParameter for an unknown key" do
      expect do
        serializer.send(:validate_filters!, [["unknown", "value"]])
      end.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
        expect(exception.message).to match(/can not be filtered by 'unknown'/i)
        expect(exception.parameter).to eq("filter")
      end
    end

    it "reports the first unknown key" do
      expect do
        serializer.send(:validate_filters!, [["name", "Alice"], ["bogus", "x"]])
      end.to raise_error(Halitosis::InvalidFilterParameter, /can not be filtered by 'bogus'/)
    end

    it "includes the resource type in the error message" do
      expect do
        serializer.send(:validate_filters!, [["nope", "x"]])
      end.to raise_error(Halitosis::InvalidFilterParameter, /items collection/)
    end

    it "sanitizes the unknown key before reflecting it" do
      expect do
        serializer.send(:validate_filters!, [["<script>alert(1)</script>", "x"]])
      end.to raise_error(Halitosis::InvalidFilterParameter, /scriptalert1script/)
    end

    it "preserves dots in unknown dot-notation keys" do
      expect do
        serializer.send(:validate_filters!, [["user.name", "x"]])
      end.to raise_error(Halitosis::InvalidFilterParameter, /can not be filtered by 'user\.name'/)
    end

    it "truncates a very long unknown key to 50 characters" do
      long_key = "a" * 100

      expect do
        serializer.send(:validate_filters!, [[long_key, "x"]])
      end.to raise_error(Halitosis::InvalidFilterParameter) do |e|
        reflected = e.message[/'([^']+)'/, 1]
        expect(reflected.length).to be <= 50
      end
    end
  end

  describe "#apply_filters!" do
    def build_context(serializer, options)
      serializer.send(:build_context, options)
    end

    context "with no filter param" do
      it "leaves the collection unchanged" do
        serializer = klass.new(items)
        context = build_context(serializer, {})

        serializer.send(:apply_filters!, context)

        expect(context.collection).to eq(items)
      end
    end

    context "with a matching filter" do
      it "filters the collection by name" do
        serializer = klass.new(items)
        context = build_context(serializer, {filter: {name: "Alice"}})

        serializer.send(:apply_filters!, context)

        expect(context.collection).to eq([{name: "Alice", score: 1}, {name: "Alice", score: 3}])
      end

      it "filters the collection by score" do
        serializer = klass.new(items)
        context = build_context(serializer, {filter: {score: "2"}})

        serializer.send(:apply_filters!, context)

        expect(context.collection).to eq([{name: "Bob", score: 2}])
      end
    end

    context "with multiple filters (AND logic)" do
      it "applies each filter in sequence" do
        serializer = klass.new(items)
        context = build_context(serializer, {filter: {name: "Alice", score: "1"}})

        serializer.send(:apply_filters!, context)

        expect(context.collection).to eq([{name: "Alice", score: 1}])
      end
    end

    context "when a filterable_by block returns nil" do
      it "raises InvalidFilterParameter with the field name and 'with the provided value'" do
        serializer = klass.new(items)
        context = build_context(serializer, {filter: {score: "not_a_number"}})

        expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
          expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
          expect(exception.message).to match(/can not be filtered by 'score' with the provided value/i)
          expect(exception.parameter).to eq("filter")
        end
      end

      it "does not include the bad value in the error message" do
        serializer = klass.new(items)
        context = build_context(serializer, {filter: {score: "sensitive_input"}})

        expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
          expect(exception.message).not_to include("sensitive_input")
        end
      end
    end

    context "with an unknown filter key" do
      it "raises InvalidFilterParameter" do
        serializer = klass.new(items)
        context = build_context(serializer, {filter: {unknown: "x"}})

        expect { serializer.send(:apply_filters!, context) }.to raise_error(
          Halitosis::InvalidFilterParameter,
          /can not be filtered by 'unknown'/
        )
      end
    end
  end
end
