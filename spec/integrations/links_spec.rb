# frozen_string_literal: true

RSpec.describe "Links" do
  let :klass do
    Class.new do
      include Halitosis

      resource :item

      attribute(:id) { resource[:id] }
    end
  end

  describe "self_link" do
    it "renders a self link" do
      klass.self_link { "/items/#{resource[:id]}" }

      expect(klass.new({id: 42}).render).to eq(
        item: {
          id: 42,
          _links: {self: {href: "/items/42"}}
        }
      )
    end
  end

  describe "link" do
    it "renders a named link" do
      klass.link(:collection) { "/items" }

      expect(klass.new({id: 1}).render).to eq(
        item: {
          id: 1,
          _links: {collection: {href: "/items"}}
        }
      )
    end

    it "renders a templated link" do
      klass.link(:find, :templated) { "/items/{?id}" }

      expect(klass.new({id: 1}).render).to eq(
        item: {
          id: 1,
          _links: {find: {href: "/items/{?id}", templated: true}}
        }
      )
    end

    it "omits links when include_links: false" do
      klass.self_link { "/items/#{resource[:id]}" }

      expect(klass.new({id: 1}, include_links: false).render).to eq(
        item: {id: 1}
      )
    end
  end

  describe "external_link" do
    it "renders an external link with type text/html" do
      klass.external_link { "https://example.com/article" }

      expect(klass.new({id: 1}).render).to eq(
        item: {
          id: 1,
          _links: {external: {href: "https://example.com/article", type: "text/html"}}
        }
      )
    end

    it "evaluates a proc type at render time" do
      klass.attribute(:pdf) { resource[:pdf] }
      klass.external_link(type: -> { resource[:pdf] ? "application/pdf" : "text/html" }) do
        resource[:url]
      end

      expect(klass.new({id: 1, url: "https://example.com/doc.pdf", pdf: true}).render).to eq(
        item: {
          id: 1,
          pdf: true,
          _links: {external: {href: "https://example.com/doc.pdf", type: "application/pdf"}}
        }
      )

      expect(klass.new({id: 2, url: "https://example.com/article", pdf: false}).render).to eq(
        item: {
          id: 2,
          pdf: false,
          _links: {external: {href: "https://example.com/article", type: "text/html"}}
        }
      )
    end
  end

  describe "self_link on a collection" do
    let :collection_klass do
      Class.new do
        include Halitosis

        collection :items do |items|
          items
        end

        self_link { "/items" }
      end
    end

    it "places the self link in the root _links" do
      expect(collection_klass.new([]).render).to eq(
        items: [],
        _links: {self: {href: "/items"}}
      )
    end
  end
end
