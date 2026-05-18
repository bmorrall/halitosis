# frozen_string_literal: true

# Minimal mock of a Kaminari/WillPaginate paginated collection.
# Wraps an array and exposes the metadata methods both adapters read.
PaginatedSlice = Struct.new(:items, :current_page, :total_pages) do
  include Enumerable

  def each(&block) = items.each(&block)
  def prev_page = (current_page > 1) ? current_page - 1 : nil
  def next_page = (current_page < total_pages) ? current_page + 1 : nil
  def previous_page = prev_page
end

# Array wrapper that supports the ActiveRecord-style offset/limit interface
# required by PagyHelper.pagy in tests that don't load a real AR adapter.
class PaginatableArray
  include Enumerable

  def initialize(items) = (@items = items.to_a)
  def each(&) = @items.each(&)
  def map(&) = @items.map(&)
  def count = @items.size
  def offset(n) = self.class.new(@items.drop(n))
  def limit(n) = self.class.new(@items.take(n))
end

RSpec.describe "Paginatable — paginate_links" do
  let :item_klass do
    Class.new do
      include Halitosis

      resource :item

      attribute(:id) { resource[:id] }
    end
  end

  let(:items) { (1..50).map { |i| {id: i} } }

  def rendered_links(items, **opts)
    item_ser = item_klass

    klass = Class.new do
      include Halitosis

      collection :items do |collection|
        collection.map { |i| item_ser.new(i) }
      end

      paginate_by_page :kaminari, default_page_size: 10 do |collection, number, size|
        offset = (number - 1) * size
        page_items = collection[offset, size] || []
        total = (collection.size.to_f / size).ceil
        PaginatedSlice.new(page_items, number, total)
      end

      paginate_links do |page_number, query_params|
        size = query_params.dig(:page, :size)
        page_number.nil? ? nil : "/items?page[number]=#{page_number}&page[size]=#{size}"
      end
    end

    klass.new(items, **opts).render
  end

  context "when on the first page" do
    subject(:result) { rendered_links(items, page: {number: 1, size: 10}) }

    let(:links) { result.fetch(:_links) }

    it "places _links at the root level, not inside the collection envelope" do
      expect(result).to have_key(:_links)
      expect(result[:items]).to be_an(Array)
    end

    it "includes first pointing to page 1" do
      expect(links[:first]).to eq("/items?page[number]=1&page[size]=10")
    end

    it "includes last pointing to the final page" do
      expect(links[:last]).to eq("/items?page[number]=5&page[size]=10")
    end

    it "emits prev as nil" do
      expect(links[:prev]).to be_nil
    end

    it "includes next pointing to page 2" do
      expect(links[:next]).to eq("/items?page[number]=2&page[size]=10")
    end
  end

  context "when on the last page" do
    let(:links) { rendered_links(items, page: {number: 5, size: 10}).fetch(:_links) }

    it "includes first pointing to page 1" do
      expect(links[:first]).to eq("/items?page[number]=1&page[size]=10")
    end

    it "includes last pointing to the final page" do
      expect(links[:last]).to eq("/items?page[number]=5&page[size]=10")
    end

    it "includes prev pointing to page 4" do
      expect(links[:prev]).to eq("/items?page[number]=4&page[size]=10")
    end

    it "emits next as nil" do
      expect(links[:next]).to be_nil
    end
  end

  context "when on a middle page" do
    let(:links) { rendered_links(items, page: {number: 3, size: 10}).fetch(:_links) }

    it "includes all four links with valid URLs" do
      expect(links[:first]).to eq("/items?page[number]=1&page[size]=10")
      expect(links[:last]).to eq("/items?page[number]=5&page[size]=10")
      expect(links[:prev]).to eq("/items?page[number]=2&page[size]=10")
      expect(links[:next]).to eq("/items?page[number]=4&page[size]=10")
    end
  end

  context "when the result is a single page" do
    let(:links) { rendered_links(few_items, page: {number: 1, size: 10}).fetch(:_links) }

    let(:few_items) { (1..5).map { |i| {id: i} } }

    it "includes first and last both pointing to page 1" do
      expect(links[:first]).to eq("/items?page[number]=1&page[size]=10")
      expect(links[:last]).to eq("/items?page[number]=1&page[size]=10")
    end

    it "emits prev as nil" do
      expect(links[:prev]).to be_nil
    end

    it "emits next as nil" do
      expect(links[:next]).to be_nil
    end
  end

  context "when forwarding query_params to the link block" do
    it "includes sort and filter params unchanged" do
      item_ser = item_klass

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        filterable_by :min_id do |collection, value|
          collection.select { |i| i[:id] >= value.to_i }
        end

        sortable_by :id do |collection, ascending|
          ascending ? collection.sort_by { |i| i[:id] } : collection.sort_by { |i| -i[:id] }
        end

        paginate_by_page :kaminari, default_page_size: 10 do |collection, number, size|
          offset = (number - 1) * size
          page_items = collection[offset, size] || []
          total = [(collection.size.to_f / size).ceil, 1].max
          PaginatedSlice.new(page_items, number, total)
        end

        paginate_links do |page_number, qp|
          page_number.nil? ? nil : "/items?captured=#{qp.to_json}"
        end
      end

      result = klass.new(items, filter: {min_id: "1"}, sort: "id", page: {number: 1, size: 10}).render
      links = result.fetch(:_links)

      captured = JSON.parse(links[:first].split("captured=").last, symbolize_names: true)
      expect(captured[:filter]).to eq(min_id: "1")
      expect(captured[:sort]).to eq("id")
      expect(captured[:page]).to eq(number: 1, size: 10)
    end
  end

  context "when no pagination procedure is declared" do
    it "raises InvalidField at DSL time" do
      item_ser = item_klass

      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection.map { |i| item_ser.new(i) }
          end

          paginate_links do |page_number, _qp|
            page_number.nil? ? nil : "/items?page=#{page_number}"
          end
        end
      end.to raise_error(Halitosis::InvalidField, /must be declared after/i)
    end
  end

  context "when no adapter is configured" do
    it "raises InvalidField at DSL time" do
      item_ser = item_klass

      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection.map { |i| item_ser.new(i) }
          end

          paginate_by_page default_page_size: 10 do |collection, number, size|
            offset = (number - 1) * size
            collection[offset, size] || []
          end

          paginate_links do |page_number, _qp|
            page_number.nil? ? nil : "/items?page=#{page_number}"
          end
        end
      end.to raise_error(Halitosis::InvalidField, /requires an adapter/i)
    end
  end

  context "with paginate_with_pagy" do
    # Minimal Pagy::Offset stand-in that actually computes page metadata.
    let(:pagy_offset_class) do
      Class.new do
        attr_reader :page, :pages, :limit, :offset

        def initialize(count:, page: 1, limit: nil, **_opts)
          @limit = limit || 10
          @page = page
          @pages = [(count.to_f / @limit).ceil, 1].max
          @offset = (page - 1) * @limit
        end

        def previous = (@page > 1) ? @page - 1 : nil
        def next = (@page < @pages) ? @page + 1 : nil
      end
    end

    let(:pagy_items) { PaginatableArray.new((1..50).map { |i| {id: i} }) }

    before { stub_const("Pagy::Offset", pagy_offset_class) }

    it "generates links using pagy metadata on the context without an explicit adapter" do
      item_ser = item_klass

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        paginate_with_pagy

        paginate_links do |page_number, query_params|
          size = query_params.dig(:page, :size)
          page_number.nil? ? nil : "/items?page[number]=#{page_number}&page[size]=#{size}"
        end
      end

      links = klass.new(pagy_items, page: {number: 2, size: 10}).render.fetch(:_links)

      expect(links[:first]).to eq("/items?page[number]=1&page[size]=10")
      expect(links[:last]).to eq("/items?page[number]=5&page[size]=10")
      expect(links[:prev]).to eq("/items?page[number]=1&page[size]=10")
      expect(links[:next]).to eq("/items?page[number]=3&page[size]=10")
    end

    it "populates query_params with page number and size from the pagy object" do
      item_ser = item_klass

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        paginate_with_pagy

        paginate_links do |_page_number, _qp|
          nil
        end
      end

      serializer = klass.new(pagy_items, page: {number: 1, size: 10})
      context = serializer.send(:build_context)
      serializer.send(:before_render, context)
      serializer.send(:render_with_context, context)

      expect(context.query_params[:page]).to eq(number: 1, size: 10)
    end

    it "forwards extra kwargs from block to Pagy::Offset" do
      item_ser = item_klass

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        paginate_with_pagy { {limit: 5} }

        paginate_links do |page_number, query_params|
          size = query_params.dig(:page, :size)
          page_number.nil? ? nil : "/items?page[number]=#{page_number}&page[size]=#{size}"
        end
      end

      links = klass.new(pagy_items, page: {number: 1}).render.fetch(:_links)

      # 50 items / limit 5 = 10 pages
      expect(links[:last]).to eq("/items?page[number]=10&page[size]=5")
    end
  end

  context "when items have an included relationship rendered by the same collection class" do
    it "renders pagination links at the root level alongside nested collection relationships" do
      collection_klass = nil

      node_klass = Class.new do
        include Halitosis

        resource :node

        attribute(:id) { resource[:id] }

        rel :children do
          collection_klass.new(resource[:children])
        end
      end

      collection_klass = Class.new do
        include Halitosis

        collection :nodes do |collection|
          collection.map { |n| node_klass.new(n) }
        end

        paginate_by_page :kaminari, default_page_size: 2 do |collection, number, size|
          offset = (number - 1) * size
          page_items = collection[offset, size] || []
          total = (collection.size.to_f / size).ceil
          PaginatedSlice.new(page_items, number, total)
        end

        paginate_links do |page_number, _qp|
          page_number.nil? ? nil : "/nodes?page[number]=#{page_number}"
        end
      end

      nodes = [
        {id: 1, children: [{id: 10, children: []}, {id: 11, children: []}]},
        {id: 2, children: [{id: 20, children: []}]},
        {id: 3, children: []},
        {id: 4, children: []}
      ]

      result = collection_klass.new(nodes, page: {number: 1, size: 2}, include: {children: true}).render

      expect(result).to have_key(:_links)
      expect(result).to have_key(:nodes)
      expect(result[:nodes]).to be_an(Array)

      expect(result[:_links][:first]).to eq("/nodes?page[number]=1")
      expect(result[:_links][:last]).to eq("/nodes?page[number]=2")
      expect(result[:_links][:prev]).to be_nil
      expect(result[:_links][:next]).to eq("/nodes?page[number]=2")

      expect(result[:nodes].first).to include(
        id: 1,
        _type: "node",
        _relationships: {
          children: [
            {id: 10, _type: "node"},
            {id: 11, _type: "node"}
          ]
        }
      )
      expect(result[:nodes][1]).to include(
        id: 2,
        _type: "node",
        _relationships: {
          children: [
            {id: 20, _type: "node"}
          ]
        }
      )
    end
  end
end
