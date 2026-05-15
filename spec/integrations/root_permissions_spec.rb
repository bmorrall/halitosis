RSpec.describe "RootPermissions" do
  context "with a resource with permission and root permission attributes" do
    let(:resource_klass) do
      Class.new do
        include Halitosis

        resource :simple

        permission(:inline_permission) { true }

        root_permission(:root_permission) { false }
      end
    end

    it "renders permission and root permission attributes" do
      serializer = resource_klass.new(Object.new)

      expect(serializer.render).to eq(
        simple: {
          _type: "simple",
          _permissions: {inline_permission: true}
        },
        _permissions: {root_permission: false}
      )
    end
  end

  context "with a collection with permission and root permission attributes" do
    let(:collection_klass) do
      Class.new do
        include Halitosis

        collection :simple do
          []
        end

        permission(:inline_permission) { true }

        root_permission(:root_permission) { false }
      end
    end

    it "renders root permission attributes" do
      serializer = collection_klass.new([])

      expect(serializer.render).to eq(
        simple: [],
        _permissions: {
          inline_permission: true,
          root_permission: false
        }
      )
    end
  end
end
