# frozen_string_literal: true

RSpec.describe Halitosis::Base do
  let :resource_serializer do
    Class.new do
      include Halitosis

      resource :test
    end
  end
  let(:resource) { double }

  describe Halitosis::Base::InstanceMethods do
    describe "#initialize" do
      it "symbolizes option keys" do
        serializer = resource_serializer.new(
          resource,
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

    describe "#render" do
      let :rendered do
        resource_serializer.new(resource).render
      end

      it "renders simple link" do
        resource_serializer.link(:label) { "href" }

        expect(rendered[:_links][:label]).to eq(href: "href")
      end

      it "does not include link if conditional checks fail" do
        resource_serializer.send(:define_method, :return_false) { false }
        resource_serializer.send(:define_method, :return_nil) { nil }

        resource_serializer.link(:label) { "href" }

        resource_serializer.link(:label_2, if: false) { "href" }
        resource_serializer.link(:label_3, if: proc { false }) { "href" }
        resource_serializer.link(:label_4, if: proc {}) { "href" }
        resource_serializer.link(:label_5, if: :return_false) { "href" }

        expect(rendered[:_links].keys).to eq([:label])
      end

      it "includes link if conditional checks pass" do
        resource_serializer.send(:define_method, :return_true) { true }
        resource_serializer.send(:define_method, :return_one) { 1 }

        resource_serializer.link(:label) { "href" }

        resource_serializer.link(:label_2, if: true) { "href" }
        resource_serializer.link(:label_3, if: proc { true }) { "href" }
        resource_serializer.link(:label_4, if: proc { 1 }) { "href" }
        resource_serializer.link(:label_5, if: :return_true) { "href" }

        expected = %i[label label_2 label_3 label_4 label_5]
        expect(rendered[:_links].keys).to eq(expected)
      end
    end

    describe "#render_child" do
      let :serializer do
        Class.new do
          include Halitosis

          property(:verify_parent) { parent.object_id }
          property(:verify_opts) { options[:include] }
        end.new
      end

      it "returns nil if child is not a serializer" do
        [nil, 1, ""].each do |child|
          expect(resource_serializer.new(resource).send(:render_child, child, {})).to be_nil
        end
      end

      it "renders child serializer with correct parent and options" do
        result = serializer.send(:render_child, serializer, foo: "bar")

        expect(result).to eq(
          verify_parent: serializer.object_id,
          verify_opts: {foo: "bar"}
        )
      end

      it "merges child options if already present" do
        serializer.options[:include] = {bar: "bar"}

        result = serializer.send(:render_child, serializer, foo: "foo")

        expect(result[:verify_opts]).to eq(foo: "foo", bar: "bar")
      end
    end

    describe "#depth" do
      it "is zero for top level serializer" do
        expect(resource_serializer.new(resource).depth).to eq(0)
      end

      it "has expected value for included children" do
        parent = resource_serializer.new(resource)

        child = resource_serializer.new(resource)
        allow(child).to receive(:parent).and_return(parent)

        grandchild = resource_serializer.new(resource)
        allow(grandchild).to receive(:parent).and_return(child)

        expect(parent.depth).to eq(0)
        expect(child.depth).to eq(1)
        expect(grandchild.depth).to eq(2)
      end
    end

    xdescribe "#as_json" do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new(resource).as_json).to eq({})
      end
    end

    describe "#to_json" do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new(resource).to_json).to eq("{}")
      end
    end

    xdescribe "#to_xml" do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new(resource).to_xml).to eq(
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n</hash>\n"
        )
      end
    end
  end
end
