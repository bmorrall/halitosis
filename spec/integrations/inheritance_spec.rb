# frozen_string_literal: true

RSpec.describe "Serializer inheritance" do
  context "with a resource serializer" do
    let(:base_klass) do
      Class.new do
        include Halitosis

        resource :item

        attribute(:id) { resource[:id] }
        attribute(:name) { resource[:name] }
        link(:self) { "/items/#{resource[:id]}" }
        root_link(:collection) { "/items" }
        meta(:version) { 1 }
        root_meta(:api_version) { 2 }
      end
    end

    context "when the child adds no fields" do
      let(:child_klass) { Class.new(base_klass) }

      it "inherits the parent's resource_type" do
        expect(child_klass.resource_type).to eq("item")
      end

      it "renders the parent's attributes" do
        result = child_klass.new({id: 1, name: "foo"}).render

        expect(result.dig(:item, :id)).to eq(1)
        expect(result.dig(:item, :name)).to eq("foo")
      end

      it "renders the parent's links" do
        result = child_klass.new({id: 1, name: "foo"}).render

        expect(result.dig(:item, :_links, :self)).to eq(href: "/items/1")
      end

      it "renders the parent's root link" do
        result = child_klass.new({id: 1, name: "foo"}).render

        expect(result.dig(:_links, :collection)).to eq(href: "/items")
      end

      it "renders the parent's meta" do
        result = child_klass.new({id: 1, name: "foo"}).render

        expect(result.dig(:item, :_meta, :version)).to eq(1)
      end

      it "renders the parent's root meta" do
        result = child_klass.new({id: 1, name: "foo"}).render

        expect(result.dig(:_meta, :api_version)).to eq(2)
      end
    end

    context "when the child adds a new attribute" do
      let(:child_klass) do
        Class.new(base_klass) do
          attribute(:extra) { "bonus" }
        end
      end

      it "renders the parent's attributes plus the child's attribute" do
        result = child_klass.new({id: 1, name: "foo"}).render

        expect(result.dig(:item, :id)).to eq(1)
        expect(result.dig(:item, :name)).to eq("foo")
        expect(result.dig(:item, :extra)).to eq("bonus")
      end
    end

    context "when the child overrides a parent attribute" do
      let(:child_klass) do
        Class.new(base_klass) do
          attribute(:name) { "overridden" }
        end
      end

      it "renders the child's version of the attribute" do
        result = child_klass.new({id: 1, name: "original"}).render

        expect(result.dig(:item, :name)).to eq("overridden")
      end

      it "still renders the parent's other attributes" do
        result = child_klass.new({id: 2, name: "original"}).render

        expect(result.dig(:item, :id)).to eq(2)
      end
    end

    context "when the child overrides a parent link" do
      let(:child_klass) do
        Class.new(base_klass) do
          link(:self) { "/v2/items/#{resource[:id]}" }
        end
      end

      it "renders the child's version of the link" do
        result = child_klass.new({id: 3, name: "foo"}).render

        expect(result.dig(:item, :_links, :self)).to eq(href: "/v2/items/3")
      end
    end

    context "when overriding does not affect the parent" do
      let(:child_klass) do
        Class.new(base_klass) do
          attribute(:name) { "overridden" }
        end
      end

      it "leaves the parent class unchanged" do
        child_klass.new({id: 1, name: "original"}).render

        result = base_klass.new({id: 1, name: "original"}).render

        expect(result.dig(:item, :name)).to eq("original")
      end
    end

    context "when the parent has a relationship" do
      let(:author_klass) do
        Class.new do
          include Halitosis

          resource :author

          attribute(:name) { resource[:name] }
        end
      end

      let(:base_klass_with_rel) do
        author_ser = author_klass

        Class.new do
          include Halitosis

          resource :item

          attribute(:id) { resource[:id] }
          relationship(:author) { author_ser.new(resource[:author]) }
        end
      end

      let(:child_klass) { Class.new(base_klass_with_rel) }

      it "renders the parent's relationship in the child" do
        result = child_klass.new({id: 1, author: {name: "Alice"}}, include: {author: true}).render

        expect(result.dig(:item, :_relationships, :author, :name)).to eq("Alice")
      end
    end
  end

  context "with a collection serializer" do
    let(:item_klass) do
      Class.new do
        include Halitosis

        resource :item

        attribute(:id) { resource[:id] }
      end
    end

    let(:base_klass) do
      item_ser = item_klass

      Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        link(:self) { "/items" }
        root_meta(:total) { 42 }
      end
    end

    context "when the child adds no fields" do
      let(:child_klass) { Class.new(base_klass) }

      it "renders the parent's collection" do
        result = child_klass.new([{id: 1}]).render

        expect(result[:items]).to contain_exactly(include(id: 1))
      end

      it "renders the parent's root link" do
        result = child_klass.new([{id: 1}]).render

        expect(result.dig(:_links, :self)).to eq(href: "/items")
      end

      it "renders the parent's root meta" do
        result = child_klass.new([{id: 1}]).render

        expect(result.dig(:_meta, :total)).to eq(42)
      end
    end

    context "when the child adds a new root_meta field" do
      let(:child_klass) do
        Class.new(base_klass) do
          root_meta(:extra) { "child_only" }
        end
      end

      it "renders both the parent's and child's root meta" do
        result = child_klass.new([{id: 1}]).render
        expect(result.dig(:_meta, :total)).to eq(42)
        expect(result.dig(:_meta, :extra)).to eq("child_only")
      end
    end
  end
end
