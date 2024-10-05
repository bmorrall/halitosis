# frozen_string_literal: true

RSpec.describe Halitosis::Base do
  let :resource_serializer do
    Class.new do
      include Halitosis::Base
    end
  end

  describe Halitosis::Base::InstanceMethods do
    describe "#initialize" do
      it "symbolizes option keys" do
        serializer = resource_serializer.new(
          "include" => {"foo" => "bar"},
          "ignore" => "this",
          :convert => "that"
        )

        expect(serializer.options).to eq(
          include: {foo: "bar"},
          ignore: "this",
          convert: "that"
        )
      end
    end

    describe "#render_child" do
      let :klass do
        Class.new do
          include Halitosis::Base
          include Halitosis::Attributes

          attribute(:verify_parent) { |context| context.parent.object_id }
          attribute(:verify_opts) { |context| context.fetch(:include) }
        end
      end

      it "returns nil if child is not a serializer" do
        serializer = klass.new
        context = serializer.send(:build_context)

        [nil, 1, ""].each do |child|
          expect(resource_serializer.new.send(:render_child, child, context, {})).to be_nil
        end
      end

      it "renders child serializer with correct parent and options" do
        serializer = klass.new
        context = serializer.send(:build_context)

        result = serializer.send(:render_child, serializer, context, foo: "bar")

        expect(result).to eq(
          verify_parent: context.object_id,
          verify_opts: {foo: "bar"}
        )
      end

      it "merges child options if already present" do
        serializer = klass.new(include: {bar: "bar"})
        context = serializer.send(:build_context)

        result = serializer.send(:render_child, serializer, context, foo: "foo")

        expect(result[:verify_opts]).to eq(foo: "foo", bar: "bar")
      end
    end

    xdescribe "#as_json" do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new.as_json).to eq({test: {}})
      end
    end

    describe "#to_json" do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new.to_json).to eq("{}")
      end
    end

    xdescribe "#to_xml" do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new.to_xml).to eq(
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n</hash>\n"
        )
      end
    end
  end
end
