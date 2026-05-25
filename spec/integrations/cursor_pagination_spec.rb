# frozen_string_literal: true

RSpec.describe "Cursor pagination" do
  let(:items) { (1..20).map { |i| {id: i} } }

  # Builds a collection serializer with cursor pagination. Pass a block to
  # add extra DSL declarations (cursor_links, cursor_meta, etc.).
  def cursor_klass(default_size: 5, &extra)
    item_ser = Class.new do
      include Halitosis

      resource :item

      attribute(:id) { resource[:id] }
    end

    klass = Class.new do
      include Halitosis

      collection :items do |collection|
        collection.map { |i| item_ser.new(i) }
      end

      paginate_by_cursor default_size: default_size do |collection, after, _before, size|
        start_id = after&.to_i || 0
        records = collection.select { |i| i[:id] > start_id }.first(size + 1)
        has_more = records.size > size
        records = records.first(size)

        Halitosis::CursorResult.new(
          records,
          next_cursor: has_more ? records.last[:id].to_s : nil,
          prev_cursor: after ? records.first[:id].to_s : nil
        )
      end
    end

    klass.class_eval(&extra) if extra
    klass
  end

  def rendered_ids(result)
    result[:items].map { |i| i[:id] }
  end

  # ── Basic pagination ────────────────────────────────────────────────────────

  context "without page params" do
    it "renders the first page using default_size" do
      result = cursor_klass.new(items).render

      expect(rendered_ids(result)).to eq((1..5).to_a)
    end
  end

  context "with page[:after]" do
    it "renders the next page from the cursor" do
      result = cursor_klass.new(items, page: {after: "5"}).render

      expect(rendered_ids(result)).to eq((6..10).to_a)
    end
  end

  context "with page[:size]" do
    it "uses the provided size" do
      result = cursor_klass.new(items, page: {size: 3}).render

      expect(rendered_ids(result)).to eq((1..3).to_a)
    end
  end

  context "when page[:after] and page[:size] are strings (e.g. from query params)" do
    it "coerces and paginates correctly" do
      result = cursor_klass.new(items, page: {after: "5", size: "3"}).render

      expect(rendered_ids(result)).to eq([6, 7, 8])
    end
  end

  context "when page[:size] is an unparseable string" do
    it "raises InvalidPaginationParameter" do
      serializer = cursor_klass.new(items, page: {size: "bad"})

      expect { serializer.render }.to raise_error do |e|
        expect(e).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(e.message).to match(/page\[size\]/i)
      end
    end
  end

  context "when the block returns nil" do
    it "raises InvalidPaginationParameter" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_cursor default_size: 5 do |_collection, _after, _before, _size|
          nil
        end
      end

      expect { klass.new(items).render }.to raise_error(Halitosis::InvalidPaginationParameter)
    end
  end

  context "when the block returns a plain collection (no CursorResult)" do
    it "renders without cursor metadata" do
      item_ser = Class.new do
        include Halitosis

        resource :item

        attribute(:id) { resource[:id] }
      end

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        paginate_by_cursor default_size: 5 do |collection, _after, _before, size|
          collection.first(size || collection.size)
        end
      end

      result = klass.new(items).render

      expect(result[:items].size).to eq(5)
      expect(result).not_to have_key(:_meta)
    end
  end

  # ── cursor_meta ─────────────────────────────────────────────────────────────

  context "with cursor_meta" do
    let(:klass) { cursor_klass { cursor_meta } }

    context "when on the first page" do
      subject(:result) { klass.new(items).render }

      it "includes a _meta key at the root level" do
        expect(result).to have_key(:_meta)
      end

      it "emits next_cursor pointing to the last item of the page" do
        expect(result[:_meta][:next_cursor]).to eq("5")
      end

      it "emits prev_cursor as nil (no after param on first page)" do
        expect(result[:_meta][:prev_cursor]).to be_nil
      end
    end

    context "when on a middle page" do
      subject(:result) { klass.new(items, page: {after: "5"}).render }

      it "emits next_cursor for the following page" do
        expect(result[:_meta][:next_cursor]).to eq("10")
      end

      it "emits prev_cursor" do
        expect(result[:_meta][:prev_cursor]).not_to be_nil
      end
    end

    context "when on the last page" do
      subject(:result) { klass.new(items, page: {after: "16"}).render }

      it "emits next_cursor as nil" do
        expect(result[:_meta][:next_cursor]).to be_nil
      end
    end

    context "with only: option" do
      let(:klass) { cursor_klass { cursor_meta only: %i[next_cursor] } }

      it "emits only the requested keys" do
        result = klass.new(items).render

        expect(result[:_meta]).to have_key(:next_cursor)
        expect(result[:_meta]).not_to have_key(:prev_cursor)
      end
    end
  end

  # ── cursor_links ─────────────────────────────────────────────────────────────

  context "with cursor_links" do
    let :klass do
      cursor_klass do
        cursor_links do |cursor, query_params|
          size = query_params.dig(:page, :size)
          cursor ? "/items?page[after]=#{cursor}&page[size]=#{size}" : nil
        end
      end
    end

    context "when on the first page" do
      subject(:result) { klass.new(items, page: {size: 5}).render }

      let(:links) { result[:_links] }

      it "places _links at the root level, not inside the collection envelope" do
        expect(result).to have_key(:_links)
        expect(result[:items]).to be_an(Array)
      end

      it "includes next pointing to the next cursor" do
        expect(links[:next]).to eq(href: "/items?page[after]=5&page[size]=5")
      end

      it "emits prev as nil (no prior cursor)" do
        expect(links[:prev]).to be_nil
      end
    end

    context "when on a middle page" do
      subject(:result) { klass.new(items, page: {after: "5", size: 5}).render }

      let(:links) { result[:_links] }

      it "includes next pointing to the next cursor" do
        expect(links[:next]).to eq(href: "/items?page[after]=10&page[size]=5")
      end

      it "includes prev" do
        expect(links[:prev]).not_to be_nil
      end
    end

    context "when on the last page" do
      subject(:result) { klass.new(items, page: {after: "16", size: 5}).render }

      let(:links) { result[:_links] }

      it "emits next as nil" do
        expect(links[:next]).to be_nil
      end
    end

    context "with only: option" do
      let :klass do
        cursor_klass do
          cursor_links(only: %i[next]) do |cursor, query_params|
            size = query_params.dig(:page, :size)
            cursor ? "/items?page[after]=#{cursor}&page[size]=#{size}" : nil
          end
        end
      end

      it "emits only the requested keys" do
        result = klass.new(items).render

        expect(result[:_links]).to have_key(:next)
        expect(result[:_links]).not_to have_key(:prev)
      end
    end
  end

  # ── DSL error cases ──────────────────────────────────────────────────────────

  context "when paginate_by_cursor is declared without a block" do
    it "raises InvalidField" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_cursor default_size: 10
        end
      end.to raise_error(Halitosis::InvalidField, /must be defined with a block/i)
    end
  end

  context "when paginate_by_cursor is declared after paginate_by_page" do
    it "raises InvalidField" do
      allow(Halitosis.config).to receive(:pagination_adapter).and_return(:kaminari)

      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page default_page_size: 10 do |collection, number, size|
            collection
          end

          paginate_by_cursor default_size: 10 do |collection, _after, _before, _size|
            collection
          end
        end
      end.to raise_error(Halitosis::InvalidField, /pagination is already defined/i)
    end
  end

  context "when paginate_by_cursor is declared twice" do
    it "raises InvalidField" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_cursor default_size: 10 do |collection, _after, _before, _size|
            collection
          end

          paginate_by_cursor default_size: 5 do |collection, _after, _before, _size|
            collection
          end
        end
      end.to raise_error(Halitosis::InvalidField, /cursor pagination is already defined/i)
    end
  end

  context "when cursor_links is declared without paginate_by_cursor" do
    it "raises InvalidField" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          cursor_links do |_cursor, _qp|
            nil
          end
        end
      end.to raise_error(Halitosis::InvalidField, /cursor_links must be declared after paginate_by_cursor/i)
    end
  end

  context "when cursor_meta is declared without paginate_by_cursor" do
    it "raises InvalidField" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          cursor_meta
        end
      end.to raise_error(Halitosis::InvalidField, /cursor_meta must be declared after paginate_by_cursor/i)
    end
  end

  context "when cursor_links block arity is wrong" do
    it "raises InvalidField" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_cursor default_size: 5 do |collection, _after, _before, _size|
            collection
          end

          cursor_links do |cursor|
            cursor
          end
        end
      end.to raise_error(Halitosis::InvalidField, /2 arguments/i)
    end
  end
end
