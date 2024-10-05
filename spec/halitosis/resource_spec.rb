RSpec.describe Halitosis::Resource do
  let(:klass) {
    Class.new { include Halitosis }
  }

  describe ".resource" do
    it "adds Halitosis::Resource to the class" do
      expect do
        klass.resource(:foo)
      end.to change(klass, :included_modules).to include(described_class)
    end
  end

  describe "#render" do
    context "with a simple resource" do
      let(:resource) { double }
      let(:serializer) { klass.new(resource) }

      before { klass.resource(:foo) }

      it "renders the response under the resource name" do
        expect(serializer.render).to eq(
          foo: {}
        )
      end

      it "renders attributes a block under the resource name" do
        klass.attribute(:bar) { "baz" }

        expect(serializer.render).to eq(
          foo: {bar: "baz"}
        )
      end

      it "renders attributes with a value under the resource name" do
        klass.attribute(:bar, value: "baz")

        expect(serializer.render).to eq(
          foo: {bar: "baz"}
        )
      end

      it "delegates to the resource for attributes without a value or block" do
        klass.attribute(:bar)

        allow(resource).to receive(:bar).and_return("baz")

        expect(serializer.render).to eq(
          foo: {bar: "baz"}
        )
      end

      it "evaluates the block in the context of the serializer" do
        def serializer.bar
          object_id
        end

        klass.attribute(:bar) { bar }

        expect(serializer.render).to eq(
          foo: {bar: serializer.object_id}
        )
      end

      it "provides a resource method within the serializer" do
        def serializer.bar
          resource.object_id
        end

        klass.attribute(:bar) { bar }

        expect(serializer.render).to eq(
          foo: {bar: resource.object_id}
        )
      end

      it "aliases the resources as the resource name" do
        def serializer.bar
          foo.object_id
        end

        klass.attribute(:bar) { bar }

        expect(serializer.render).to eq(
          foo: {bar: resource.object_id}
        )
      end
    end
  end
end
