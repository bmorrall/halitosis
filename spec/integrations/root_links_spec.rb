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

  context "with a sortable collection and a self root link using query_params" do
    let(:collection_klass) do
      Class.new do
        include Halitosis

        collection :items do |items|
          items
        end

        sortable_by :name do |collection, ascending|
          ascending ? collection.sort : collection.sort.reverse
        end

        root_link(:self) do |query_params|
          "/items?#{query_params.map { |k, v| "#{k}=#{v}" }.join("&")}"
        end
      end
    end

    it "includes accumulated query params in the self link" do
      serializer = collection_klass.new(["b", "a"], sort: "name")

      expect(serializer.render[:_links][:self]).to eq(href: "/items?sort=name")
    end

    it "renders an empty query string when no params are accumulated" do
      serializer = collection_klass.new(["b", "a"])

      expect(serializer.render[:_links][:self]).to eq(href: "/items?")
    end
  end

  context "with a resource and a self root link using query_params" do
    let(:resource_klass) do
      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :item

        relationship(:comments) { nil }

        root_link(:self) do |query_params|
          "/item?#{query_params.map { |k, v| "#{k}=#{v}" }.join("&")}"
        end
      end
    end

    it "includes the include param when an include option is passed" do
      serializer = resource_klass.new(Object.new, include: "comments")

      expect(serializer.render[:_links][:self]).to eq(href: "/item?include=comments")
    end

    it "renders an empty query string when no params are accumulated" do
      serializer = resource_klass.new(Object.new)

      expect(serializer.render[:_links][:self]).to eq(href: "/item?")
    end
  end

  context "with a root link block accepting context and query_params (2-arg)" do
    let(:resource_klass) do
      Class.new do
        include Halitosis

        resource :item

        root_link(:self) do |ctx, query_params|
          "/items/#{ctx.fetch(:id)}?#{query_params.map { |k, v| "#{k}=#{v}" }.join("&")}"
        end
      end
    end

    it "passes context and query_params to the block" do
      serializer = resource_klass.new(Object.new, id: 99)

      expect(serializer.render[:_links][:self]).to eq(href: "/items/99?")
    end
  end

  context "when a root_link block returns nil" do
    let(:resource_klass) do
      Class.new do
        include Halitosis

        resource :item

        root_link(:conditional) { nil }
      end
    end

    it "omits the link from the output" do
      result = resource_klass.new(Object.new).render

      expect(result).not_to have_key(:_links)
    end
  end
end
