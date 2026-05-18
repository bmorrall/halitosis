# frozen_string_literal: true

RSpec.describe Halitosis::Preloadable do
  let(:klass) do
    Class.new do
      include Halitosis::Base
      include Halitosis::Preloadable

      def computed_value
        "from_instance"
      end
    end
  end

  let(:serializer) { klass.new }
  let(:context) { serializer.send(:build_context) }

  describe Halitosis::Preloadable::InstanceMethods do
    describe "#store_preload" do
      context "with a proc value_source" do
        it "stores the evaluated result" do
          serializer.send(:store_preload, context, :my_field, proc { "proc_value" })

          expect(context.fetch_local(:includeable_preloads)).to eq(my_field: "proc_value")
        end
      end

      context "with a symbol value_source" do
        it "calls the method on the serializer instance and stores the result" do
          serializer.send(:store_preload, context, :my_field, :computed_value)

          expect(context.fetch_local(:includeable_preloads)).to eq(my_field: "from_instance")
        end
      end

      context "with a string value_source" do
        it "calls the method on the serializer instance and stores the result" do
          serializer.send(:store_preload, context, :my_field, "computed_value")

          expect(context.fetch_local(:includeable_preloads)).to eq(my_field: "from_instance")
        end
      end

      it "does not clobber existing preloads for other fields" do
        serializer.send(:store_preload, context, :field_a, proc { "a" })
        serializer.send(:store_preload, context, :field_b, proc { "b" })

        preloads = context.fetch_local(:includeable_preloads)

        expect(preloads[:field_a]).to eq("a")
        expect(preloads[:field_b]).to eq("b")
      end

      it "stores a string field_name as a symbol key" do
        serializer.send(:store_preload, context, "my_field", proc { "value" })

        expect(context.fetch_local(:includeable_preloads)).to have_key(:my_field)
      end

      it "overwrites an existing entry for the same field" do
        serializer.send(:store_preload, context, :my_field, proc { "first" })
        serializer.send(:store_preload, context, :my_field, proc { "second" })

        expect(context.fetch_local(:includeable_preloads)[:my_field]).to eq("second")
      end
    end

    describe "#fetch_preload" do
      it "returns the stored value" do
        serializer.send(:store_preload, context, :my_field, proc { "value" })

        expect(serializer.send(:fetch_preload, context, :my_field)).to eq("value")
      end

      it "lazily evaluates the serializer method and caches the value on first access" do
        expect(serializer.send(:fetch_preload, context, :computed_value)).to eq("from_instance")

        expect(serializer.send(:preloaded?, context, :computed_value)).to be true
      end

      it "does not re-evaluate the method on subsequent fetches" do
        call_count = 0
        klass.define_method(:counted_value) { call_count += 1 }

        serializer.send(:fetch_preload, context, :counted_value)
        serializer.send(:fetch_preload, context, :counted_value)

        expect(call_count).to eq(1)
      end

      it "returns nil when the stored value is nil" do
        serializer.send(:store_preload, context, :my_field, proc {})

        expect(serializer.send(:fetch_preload, context, :my_field)).to be_nil
      end

      it "accepts a string field_name" do
        serializer.send(:store_preload, context, :my_field, proc { "value" })

        expect(serializer.send(:fetch_preload, context, "my_field")).to eq("value")
      end
    end

    describe "#preloaded?" do
      it "returns true when a value has been stored" do
        serializer.send(:store_preload, context, :my_field, proc { "value" })

        expect(serializer.send(:preloaded?, context, :my_field)).to be true
      end

      it "returns false when no value has been stored for the field" do
        expect(serializer.send(:preloaded?, context, :my_field)).to be false
      end

      it "returns false when no preloads have been stored at all" do
        expect(serializer.send(:preloaded?, context, :anything)).to be false
      end

      it "returns true even when the stored value is nil" do
        serializer.send(:store_preload, context, :my_field, proc {})

        expect(serializer.send(:preloaded?, context, :my_field)).to be true
      end

      it "accepts a string field_name" do
        serializer.send(:store_preload, context, :my_field, proc { "value" })

        expect(serializer.send(:preloaded?, context, "my_field")).to be true
      end
    end
  end
end
