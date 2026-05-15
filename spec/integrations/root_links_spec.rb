RSpec.describe "RootLinks" do
  context "with a resource with link and root link attributes" do
    let(:resource_klass) do
      Class.new do
        include Halitosis

        resource :simple

        link(:inline_link) { "https://example.com/inline" }

        root_link(:root_link) { "https://example.com/root" }
      end
    end

    it "renders link and root link attributes" do
      serializer = resource_klass.new(Object.new)

      expect(serializer.render).to eq(
        simple: {
          _type: "simple",
          _links: {inline_link: {href: "https://example.com/inline"}}
        },
        _links: {root_link: {href: "https://example.com/root"}}
      )
    end
  end

  context "with a collection with link and root link attributes" do
    let(:collection_klass) do
      Class.new do
        include Halitosis

        collection :simple do
          []
        end

        link(:inline_link) { "https://example.com/inline" }

        root_link(:root_link) { "https://example.com/root" }
      end
    end

    it "renders root link attributes" do
      serializer = collection_klass.new([])

      expect(serializer.render).to eq(
        simple: [],
        _links: {
          inline_link: {href: "https://example.com/inline"},
          root_link: {href: "https://example.com/root"}
        }
      )
    end
  end
end
