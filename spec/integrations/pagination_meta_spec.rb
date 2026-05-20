# frozen_string_literal: true

# Reuse the helpers defined in pagination_links_spec.rb if loaded first, or
# define lightweight stand-ins so this spec can run independently.
unless defined?(PaginatedSlice)
  PaginatedSlice = Struct.new(:items, :current_page, :total_pages, :per_page, :total_entries) do
    include Enumerable

    def each(&block) = items.each(&block)
    def prev_page = (current_page > 1) ? current_page - 1 : nil
    def next_page = (current_page < total_pages) ? current_page + 1 : nil
    def previous_page = prev_page
    def limit_value = per_page
    def total_count = total_entries
  end
end

RSpec.describe "Paginatable — paginate_meta" do
  let :item_klass do
    Class.new do
      include Halitosis

      resource :item

      attribute(:id) { resource[:id] }
    end
  end

  let(:items) { (1..50).map { |i| {id: i} } }

  def rendered_meta(items, **opts)
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
        PaginatedSlice.new(page_items, number, total, size, collection.size)
      end

      paginate_meta
    end

    klass.new(items, **opts).render
  end

  context "when on the first page" do
    subject(:result) { rendered_meta(items, page: {number: 1, size: 10}) }

    let(:meta) { result.fetch(:_meta) }

    it "places _meta at the root level" do
      expect(result).to have_key(:_meta)
      expect(result[:items]).to be_an(Array)
    end

    it "includes first" do
      expect(meta[:first]).to eq(1)
    end

    it "includes last" do
      expect(meta[:last]).to eq(5)
    end

    it "includes prev as nil" do
      expect(meta[:prev]).to be_nil
    end

    it "includes next" do
      expect(meta[:next]).to eq(2)
    end

    it "includes self" do
      expect(meta[:self]).to eq(1)
    end
  end

  context "when on the last page" do
    let(:meta) { rendered_meta(items, page: {number: 5, size: 10}).fetch(:_meta) }

    it "includes first" do
      expect(meta[:first]).to eq(1)
    end

    it "includes last" do
      expect(meta[:last]).to eq(5)
    end

    it "includes prev" do
      expect(meta[:prev]).to eq(4)
    end

    it "includes next as nil" do
      expect(meta[:next]).to be_nil
    end

    it "includes self" do
      expect(meta[:self]).to eq(5)
    end
  end

  context "when on a middle page" do
    let(:meta) { rendered_meta(items, page: {number: 3, size: 10}).fetch(:_meta) }

    it "includes all five navigational page numbers" do
      expect(meta[:self]).to eq(3)
      expect(meta[:first]).to eq(1)
      expect(meta[:last]).to eq(5)
      expect(meta[:prev]).to eq(2)
      expect(meta[:next]).to eq(4)
    end
  end

  context "when the result is a single page" do
    let(:few_items) { (1..5).map { |i| {id: i} } }
    let(:meta) { rendered_meta(few_items, page: {number: 1, size: 10}).fetch(:_meta) }

    it "includes all five navigational page numbers" do
      expect(meta[:self]).to eq(1)
      expect(meta[:first]).to eq(1)
      expect(meta[:last]).to eq(1)
      expect(meta[:prev]).to be_nil
      expect(meta[:next]).to be_nil
    end
  end

  context "when only: limits the emitted meta keys" do
    it "only emits the specified meta keys" do
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
          PaginatedSlice.new(page_items, number, total, size, collection.size)
        end

        paginate_meta only: %i[current_page total_pages]
      end

      meta = klass.new(items, page: {number: 3, size: 10}).render.fetch(:_meta)

      expect(meta.keys).to contain_exactly(:current_page, :total_pages)
      expect(meta[:current_page]).to eq(3)
      expect(meta[:total_pages]).to eq(5)
    end

    it "can emit all four extended collection metadata keys" do
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
          PaginatedSlice.new(page_items, number, total, size, collection.size)
        end

        paginate_meta only: %i[current_page per_page total_entries total_pages]
      end

      meta = klass.new(items, page: {number: 2, size: 10}).render.fetch(:_meta)

      expect(meta.keys).to contain_exactly(:current_page, :per_page, :total_entries, :total_pages)
      expect(meta[:current_page]).to eq(2)
      expect(meta[:per_page]).to eq(10)
      expect(meta[:total_entries]).to eq(50)
      expect(meta[:total_pages]).to eq(5)
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

          paginate_meta
        end
      end.to raise_error(Halitosis::InvalidField, /must be declared after/i)
    end
  end

  context "when combined with paginate_links" do
    it "emits both _links and _meta at the root level" do
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
          PaginatedSlice.new(page_items, number, total, size, collection.size)
        end

        paginate_links do |page_number, query_params|
          size = query_params.dig(:page, :size)
          page_number.nil? ? nil : "/items?page[number]=#{page_number}&page[size]=#{size}"
        end

        paginate_meta
      end

      result = klass.new(items, page: {number: 2, size: 10}).render

      expect(result).to have_key(:_links)
      expect(result).to have_key(:_meta)

      expect(result[:_links][:first]).to eq(href: "/items?page[number]=1&page[size]=10")
      expect(result[:_meta][:self]).to eq(2)
      expect(result[:_meta][:first]).to eq(1)
      expect(result[:_meta][:last]).to eq(5)
      expect(result[:_meta][:prev]).to eq(1)
      expect(result[:_meta][:next]).to eq(3)
    end
  end

  context "when combining with other root_meta fields" do
    it "merges pagination page numbers into existing _meta" do
      item_ser = item_klass

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        root_meta(:total_count) { 50 }

        paginate_by_page :kaminari, default_page_size: 10 do |collection, number, size|
          offset = (number - 1) * size
          page_items = collection[offset, size] || []
          total = (collection.size.to_f / size).ceil
          PaginatedSlice.new(page_items, number, total, size, collection.size)
        end

        paginate_meta
      end

      result = klass.new(items, page: {number: 1, size: 10}).render
      meta = result.fetch(:_meta)

      expect(meta[:total_count]).to eq(50)
      expect(meta[:self]).to eq(1)
      expect(meta[:first]).to eq(1)
      expect(meta[:last]).to eq(5)
      expect(meta[:prev]).to be_nil
      expect(meta[:next]).to eq(2)
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

          paginate_by_page(default_page_size: 10) { |collection, number, size|
            offset = (number - 1) * size
            collection[offset, size] || []
          }

          paginate_meta
        end
      end.to raise_error(Halitosis::InvalidField, /requires an adapter/i)
    end
  end

  context "when a global pagination adapter is configured" do
    it "uses the config adapter when none is passed" do
      item_ser = item_klass

      allow(Halitosis.config).to receive(:pagination_adapter).and_return(:kaminari)

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        paginate_by_page default_page_size: 10 do |collection, number, size|
          offset = (number - 1) * size
          page_items = collection[offset, size] || []
          total = (collection.size.to_f / size).ceil
          PaginatedSlice.new(page_items, number, total, size, collection.size)
        end

        paginate_meta
      end

      meta = klass.new(items, page: {number: 1, size: 10}).render.fetch(:_meta)

      expect(meta[:self]).to eq(1)
      expect(meta[:first]).to eq(1)
      expect(meta[:last]).to eq(5)
      expect(meta[:prev]).to be_nil
      expect(meta[:next]).to eq(2)
    end
  end
end
