RSpec.describe Halitosis::Resource do
  let(:klass) {
    Class.new {
      include Halitosis
      include Halitosis::Resource
    }
  }

  describe ".included" do
    it "raises error if base is already a collection" do
      collection_class = Class.new {
        include Halitosis
        include Halitosis::Collection
      }

      expect {
        collection_class.send :include, described_class
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidResource)
        expect(exception.message).to match(/has already defined a collection/i)
      end
    end

    it "declares a resource accessor" do
      resource = double
      serializer = klass.new(resource)
      expect(serializer.resource).to be(resource)
    end
  end

  describe ".define_resource" do
    it "sets a resource type" do
      klass.define_resource(:foo)

      expect(klass.resource_type).to eq("foo")
    end

    it "declares a named resource accessor" do
      resource = double

      klass.define_resource(:foo)

      serializer = klass.new(resource)
      expect(serializer.foo).to be(resource)
    end

    it "handles string arguments" do
      klass.define_resource("foo")

      expect(klass.resource_type).to eq("foo")
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
