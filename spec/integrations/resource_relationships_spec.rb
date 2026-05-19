RSpec.describe "ResourceRelationships" do
  context "with a relationship declared with a link: proc" do
    let(:author_klass) do
      Class.new do
        include Halitosis

        resource :author
        attribute(:name) { resource[:name] }
      end
    end

    let(:article_klass) do
      author = author_klass

      Class.new do
        include Halitosis

        resource :article

        relationship(:author, link: -> { "/people/#{resource[:author_id]}" }) do
          author.new(resource[:author])
        end
      end
    end

    it "renders the link in _links regardless of include" do
      result = article_klass.new({author_id: 5, author: {name: "Alice"}}).render

      expect(result.dig(:article, :_links, :author)).to eq(href: "/people/5")
      expect(result[:article]).not_to have_key(:_relationships)
    end

    it "renders both the link and the relationship data when included" do
      result = article_klass.new({author_id: 5, author: {name: "Alice"}}, include: :author).render

      expect(result.dig(:article, :_links, :author)).to eq(href: "/people/5")
      expect(result.dig(:article, :_relationships, :author, :name)).to eq("Alice")
    end
  end

  context "with a relationship declared with a static string link:" do
    it "renders the link in _links" do
      klass = Class.new do
        include Halitosis

        resource :item
        relationship(:docs, link: "/docs/items") { nil }
      end

      result = klass.new(Object.new).render

      expect(result.dig(:item, :_links, :docs)).to eq(href: "/docs/items")
    end
  end

  context "with a relationship declared with a link: and an if: guard" do
    it "hides the link when the if: guard is false" do
      klass = Class.new do
        include Halitosis

        resource :item
        relationship(:author, if: proc { false }, link: -> { "/people/1" }) { nil }
      end

      result = klass.new(Object.new).render

      expect(result.dig(:item, :_links)).to be_nil
    end
  end

  context "with a relationship declared with a link: and an unless: guard" do
    it "hides the link when the unless: guard is true" do
      klass = Class.new do
        include Halitosis

        resource :item
        relationship(:author, unless: proc { true }, link: -> { "/people/1" }) { nil }
      end

      result = klass.new(Object.new).render

      expect(result.dig(:item, :_links)).to be_nil
    end
  end
end
