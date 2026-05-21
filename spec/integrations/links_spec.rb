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
