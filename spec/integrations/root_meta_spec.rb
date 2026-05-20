RSpec.describe "RootMeta" do
  context "with a resource with meta and root meta attributes" do
    let(:resource_klass) do
      Class.new do
        include Halitosis

        resource :simple

        meta(:inline_meta) { "inline meta" }

        root_meta(:root_meta) { "root meta" }
      end
    end

    it "renders meta and root meta attributes" do
      serializer = resource_klass.new(Object.new)

      expect(serializer.render).to eq(
        simple: {
          _meta: {inline_meta: "inline meta"}
        },
        _meta: {root_meta: "root meta"}
      )
    end
  end

  context "with a collection with meta and root meta attributes" do
    let(:collection_klass) do
      Class.new do
        include Halitosis

        collection :simple do
          []
        end

        meta(:inline_meta) { "inline meta" }

        root_meta(:root_meta) { "root meta" }
      end
    end

    it "renders root meta attributes" do
      serializer = collection_klass.new([])

      expect(serializer.render).to eq(
        simple: [],
        _meta: {
          inline_meta: "inline meta",
          root_meta: "root meta"
        }
      )
    end
  end

  context "with a collection and a root meta block that receives the collection" do
    let(:collection_klass) do
      Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        root_meta(:count) { |collection| collection.size }
      end
    end

    it "passes the collection to the root meta block" do
      expect(collection_klass.new([1, 2, 3]).render[:_meta]).to eq(count: 3)
      expect(collection_klass.new([]).render[:_meta]).to eq(count: 0)
    end
  end
end
