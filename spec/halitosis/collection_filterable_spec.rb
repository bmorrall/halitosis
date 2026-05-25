# frozen_string_literal: true

RSpec.describe Halitosis::CollectionFilterable do
  let :klass do
    Class.new do
      include Halitosis

      collection :items do |items|
        items
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

    it "raises InvalidField when the block accepts more than 3 arguments" do
      expect do
        klass.filterable_by(:title) { |a, b, c, d| a }
      end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*2 arguments.*or 3 arguments/i)
    end

    it "accepts a 3-argument block (collection, value, errors)" do
      expect do
        klass.filterable_by(:title) { |collection, value, errors| collection }
      end.not_to raise_error
    end

    context "with a zero-arity namespace block" do
      it "registers nested fields with dot-prefixed names" do
        ns_klass = Class.new do
          include Halitosis

          collection :items do |items|
            items
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

          collection :items do |items|
            items
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

          collection :items do |items|
            items
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

      it "raises InvalidField when a nested block accepts more than 3 arguments" do
        expect do
          Class.new do
            include Halitosis

            collection :items do |items|
              items
            end

            filterable_by :user do
              filterable_by :name do |a, b, c, d|
                a
              end
            end
          end
        end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*2 arguments.*or 3 arguments/i)
      end

      it "accepts a nested 3-argument block (collection, value, errors)" do
        expect do
          Class.new do
            include Halitosis

            collection :items do |items|
              items
            end

            filterable_by :user do
              filterable_by :name do |collection, value, errors|
                collection
              end
            end
          end
        end.not_to raise_error
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
        expect(exception.parameter).to eq("filter[unknown]")
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

    context "when a filterable_by block (arity-3) adds errors" do
      let :errors_klass do
        Class.new do
          include Halitosis

          collection :items do |items|
            items
          end

          filterable_by :status do |collection, value, errors|
            unless %w[active inactive].include?(value)
              errors.add("must be 'active' or 'inactive'")
            end
            errors.none? ? collection.select { |i| i[:status] == value } : nil
          end
        end
      end

      it "raises InvalidFilterParameter with the custom message" do
        serializer = errors_klass.new(items)
        context = build_context(serializer, {filter: {status: "bogus"}})

        expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
          expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
          expect(exception.message).to match(/can not be filtered by 'status': must be 'active' or 'inactive'/i)
          expect(exception.parameter).to eq("filter[status]")
        end
      end

      it "does not raise when the block adds no errors" do
        items_with_status = [{name: "Alice", status: "active"}, {name: "Bob", status: "inactive"}]
        serializer = errors_klass.new(items_with_status)
        context = build_context(serializer, {filter: {status: "active"}})

        expect { serializer.send(:apply_filters!, context) }.not_to raise_error
        expect(context.collection).to eq([{name: "Alice", status: "active"}])
      end

      context "with a nested filter" do
        let :nested_errors_klass do
          Class.new do
            include Halitosis

            collection :items do |items|
              items
            end

            filterable_by :article do
              filterable_by :name do |collection, value, errors|
                errors.add("is too short") if value.length < 3
                errors.none? ? collection.select { |i| i[:name] == value } : nil
              end
            end
          end
        end

        it "uses bracket notation for the source parameter" do
          items_data = [{name: "Alice"}, {name: "Bob"}]
          serializer = nested_errors_klass.new(items_data)
          context = build_context(serializer, {filter: {article: {name: "Al"}}})

          expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
            expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
            expect(exception.message).to match(/can not be filtered by 'article\.name': is too short/i)
            expect(exception.parameter).to eq("filter[article][name]")
          end
        end
      end

      context "when the block passes a field name override to errors.add" do
        let :override_klass do
          Class.new do
            include Halitosis

            collection :items do |items|
              items
            end

            filterable_by :date_range do |collection, value, errors|
              errors.add("started_at", "is not a valid date") unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
              errors.none? ? collection : nil
            end
          end
        end

        it "reports under the overridden field name" do
          serializer = override_klass.new(items)
          context = build_context(serializer, {filter: {date_range: "not-a-date"}})

          expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
            expect(exception.message).to match(/can not be filtered by 'started_at': is not a valid date/i)
            expect(exception.parameter).to eq("filter[started_at]")
          end
        end

        context "with a namespace prefix" do
          let :nested_override_klass do
            Class.new do
              include Halitosis

              collection :items do |items|
                items
              end

              filterable_by :account do
                filterable_by :date_range do |collection, value, errors|
                  errors.add("started_at", "is not a valid date") unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
                  errors.none? ? collection : nil
                end
              end
            end
          end

          it "prepends the namespace prefix to the overridden field name" do
            serializer = nested_override_klass.new(items)
            context = build_context(serializer, {filter: {account: {date_range: "not-a-date"}}})

            expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
              expect(exception.message).to match(/can not be filtered by 'account\.started_at': is not a valid date/i)
              expect(exception.parameter).to eq("filter[account][started_at]")
            end
          end
        end
      end
    end

    context "when a filterable_by block returns nil" do
      it "raises InvalidFilterParameter with the field name and 'with the provided value'" do
        serializer = klass.new(items)
        context = build_context(serializer, {filter: {score: "not_a_number"}})

        expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
          expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
          expect(exception.message).to match(/can not be filtered by 'score': The provided value is invalid\./i)
          expect(exception.parameter).to eq("filter[score]")
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

    context "with a compound filter (keys: option)" do
      let :compound_klass do
        Class.new do
          include Halitosis

          collection :items do |items|
            items
          end

          filterable_by :start_date, keys: [:from, :to] do |collection, value|
            collection.select { |i| i[:date].between?(value[:from], value[:to]) }
          end
        end
      end

      let(:dated_items) do
        [
          {name: "Alice", date: "2024-01-15"},
          {name: "Bob", date: "2024-06-01"},
          {name: "Carol", date: "2024-09-20"}
        ]
      end

      it "passes a symbolized hash value to the block" do
        serializer = compound_klass.new(dated_items)
        context = build_context(serializer, {filter: {start_date: {from: "2024-01-01", to: "2024-07-01"}}})

        serializer.send(:apply_filters!, context)

        expect(context.collection).to eq([{name: "Alice", date: "2024-01-15"}, {name: "Bob", date: "2024-06-01"}])
      end

      it "raises InvalidFilterParameter for an unknown sub-key" do
        serializer = compound_klass.new(dated_items)
        context = build_context(serializer, {filter: {start_date: {from: "2024-01-01", foo: "bar"}}})

        expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
          expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
          expect(exception.message).to match(/can not be filtered by 'start_date\.foo'/i)
        end
      end

      it "passes partial keys to the block without raising a framework error" do
        safe_compound_klass = Class.new do
          include Halitosis

          collection :items do |items|
            items
          end

          filterable_by :start_date, keys: [:from, :to] do |collection, value|
            # only :from present — block receives it and guards gracefully
            collection.select { |i| i[:date] >= value[:from] }
          end
        end

        serializer = safe_compound_klass.new(dated_items)
        context = build_context(serializer, {filter: {start_date: {from: "2024-06-01"}}})

        expect { serializer.send(:apply_filters!, context) }.not_to raise_error
        expect(context.collection).to eq([{name: "Bob", date: "2024-06-01"}, {name: "Carol", date: "2024-09-20"}])
      end

      context "with a 3-argument block" do
        let :compound_errors_klass do
          Class.new do
            include Halitosis

            collection :items do |items|
              items
            end

            filterable_by :start_date, keys: [:from, :to] do |collection, value, errors|
              errors.add("from", "is required") unless value.key?(:from)
              errors.add("to", "is required") unless value.key?(:to)
              errors.none? ? collection.select { |i| i[:date].between?(value[:from], value[:to]) } : nil
            end
          end
        end

        it "reports sub-key errors under the compound field name" do
          serializer = compound_errors_klass.new(dated_items)
          context = build_context(serializer, {filter: {start_date: {from: "2024-01-01"}}})

          expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
            expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
            expect(exception.message).to match(/can not be filtered by 'start_date\.to': is required/i)
            expect(exception.parameter).to eq("filter[start_date][to]")
          end
        end

        it "reports a top-level error under the compound field name itself" do
          klass_with_range_check = Class.new do
            include Halitosis

            collection :items do |items|
              items
            end

            filterable_by :start_date, keys: [:from, :to] do |collection, value, errors|
              errors.add("range is too wide") if value[:from] && value[:to] && (value[:to] > value[:from])
              errors.none? ? collection : nil
            end
          end

          serializer = klass_with_range_check.new(dated_items)
          context = build_context(serializer, {filter: {start_date: {from: "2024-01-01", to: "2024-12-31"}}})

          expect { serializer.send(:apply_filters!, context) }.to raise_error do |exception|
            expect(exception.message).to match(/can not be filtered by 'start_date': range is too wide/i)
            expect(exception.parameter).to eq("filter[start_date]")
          end
        end
      end
    end
  end

  describe "context query_params" do
    it "registers a symbolized filter hash after rendering" do
      context = render_context(klass.new(items, filter: {name: "Alice"}))

      expect(context.query_params[:filter]).to eq(name: "Alice")
    end

    it "does not register a filter key when no filter param is present" do
      context = render_context(klass.new(items))

      expect(context.query_params).to eq({})
    end

    it "preserves nested filter keys" do
      ns_klass = Class.new do
        include Halitosis

        collection :items do |items|
          items
        end

        filterable_by :user do
          filterable_by :name do |coll, value|
            coll.select { |i| i[:name] == value }
          end
        end
      end

      context = render_context(ns_klass.new(items, filter: {user: {name: "Alice"}}))

      expect(context.query_params[:filter]).to eq(user: {name: "Alice"})
    end
  end
end
