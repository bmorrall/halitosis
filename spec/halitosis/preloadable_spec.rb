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
    describe "#preload_context" do
      it "is a no-op by default" do
        expect { serializer.preload_context(context) }.not_to raise_error
      end

      it "is called during before_render" do
        calls = []
        klass.define_method(:preload_context) { |ctx| calls << ctx }

        serializer.send(:before_render, context)

        expect(calls).to eq([context])
      end
    end

    describe "#before_render" do
      it "calls super" do
        super_called = false
        klass.define_method(:before_render) do |ctx|
          super_called = true
          super(ctx)
        end

        serializer.send(:before_render, context)

        expect(super_called).to be true
      end

      it "returns nil" do
        expect(serializer.send(:before_render, context)).to be_nil
      end
    end

    describe "#store_preload" do
      it "stores the given value" do
        serializer.send(:store_preload, context, :my_field, "stored_value")

        expect(context.fetch_local(:preloaded)).to eq(my_field: "stored_value")
      end

      it "does not clobber existing preloads for other fields" do
        serializer.send(:store_preload, context, :field_a, "a")
        serializer.send(:store_preload, context, :field_b, "b")

        preloads = context.fetch_local(:preloaded)

        expect(preloads[:field_a]).to eq("a")
        expect(preloads[:field_b]).to eq("b")
      end

      it "stores a string field_name as a symbol key" do
        serializer.send(:store_preload, context, "my_field", "value")

        expect(context.fetch_local(:preloaded)).to have_key(:my_field)
      end

      it "overwrites an existing entry for the same field" do
        serializer.send(:store_preload, context, :my_field, "first")
        serializer.send(:store_preload, context, :my_field, "second")

        expect(context.fetch_local(:preloaded)[:my_field]).to eq("second")
      end
    end

    describe "#fetch_preload" do
      it "returns the stored value" do
        serializer.send(:store_preload, context, :my_field, "value")

        expect(serializer.send(:fetch_preload, context, :my_field)).to eq("value")
      end

      it "returns nil when nothing has been stored for the field" do
        expect(serializer.send(:fetch_preload, context, :my_field)).to be_nil
      end

      it "returns nil when the stored value is nil" do
        serializer.send(:store_preload, context, :my_field, nil)

        expect(serializer.send(:fetch_preload, context, :my_field)).to be_nil
      end

      it "accepts a string field_name" do
        serializer.send(:store_preload, context, :my_field, "value")

        expect(serializer.send(:fetch_preload, context, "my_field")).to eq("value")
      end
    end

    describe "#preloaded?" do
      it "returns true when a value has been stored" do
        serializer.send(:store_preload, context, :my_field, "value")

        expect(serializer.send(:preloaded?, context, :my_field)).to be true
      end

      it "returns false when no value has been stored for the field" do
        expect(serializer.send(:preloaded?, context, :my_field)).to be false
      end

      it "returns false when no preloads have been stored at all" do
        expect(serializer.send(:preloaded?, context, :anything)).to be false
      end

      it "returns true even when the stored value is nil" do
        serializer.send(:store_preload, context, :my_field, nil)

        expect(serializer.send(:preloaded?, context, :my_field)).to be true
      end

      it "accepts a string field_name" do
        serializer.send(:store_preload, context, :my_field, "value")

        expect(serializer.send(:preloaded?, context, "my_field")).to be true
      end
    end
  end
end
