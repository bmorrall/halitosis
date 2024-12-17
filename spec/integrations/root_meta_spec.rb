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
end
