# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable do
  let :klass do
    Class.new do
      include Halitosis

      collection :items do |collection|
        collection
      end

      paginate_by_page :kaminari, default_page_size: 10 do |collection, number, size|
        offset = (number - 1) * size
        collection[offset, size] || []
      end
    end
  end

  let(:items) { (1..50).map { |i| {id: i} } }

  describe ".paginate_with" do
    before { allow(Halitosis.config).to receive(:pagination_adapter).and_return(:kaminari) }

    it "stores the pagination procedure" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_with do |context, collection, page|
          collection.drop(page[:offset].to_i).first(page[:size].to_i)
        end
      end

      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::Field)).not_to be_nil
    end

    it "raises InvalidField without a block" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_with
        end
      end.to raise_error(Halitosis::InvalidField, /paginate_with must be defined with a block/i)
    end

    it "raises InvalidField when declared a second time" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_with { |context, collection, page| collection }
          paginate_with { |context, collection, page| collection }
        end
      end.to raise_error(Halitosis::InvalidField, /pagination is already defined/i)
    end

    it "passes the page hash from context to the block" do
      received = nil

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_with do |context, collection, page|
          received = page
          collection
        end
      end

      serializer = klass.new([])
      serializer.send(:apply_pagination!, serializer.send(:build_context, {page: {cursor: "abc"}}))

      expect(received).to eq({cursor: "abc"})
    end

    it "passes an empty hash when page is absent from context" do
      received = nil

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_with do |context, collection, page|
          received = page
          collection
        end
      end

      serializer = klass.new([])
      serializer.send(:apply_pagination!, serializer.send(:build_context, {}))

      expect(received).to eq({})
    end
  end

  describe ".paginate_by_page" do
    before { allow(Halitosis.config).to receive(:pagination_adapter).and_return(:kaminari) }

    it "stores the pagination procedure" do
      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::Field)).not_to be_nil
    end

    it "raises InvalidField without a block when the adapter has no default procedure" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page ->(collection) { {} }, default_page_size: 10
        end
      end.to raise_error(Halitosis::InvalidField, /paginate_by_page must be defined with a block/i)
    end

    it "uses the adapter's default_per_page_procedure when no block is given" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page :kaminari, default_page_size: 10
      end

      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::Field)).not_to be_nil
    end

    it "raises InvalidField when declared a second time" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
          paginate_by_page(default_page_size: 25) { |collection, number, size| collection }
        end
      end.to raise_error(Halitosis::InvalidField, /pagination is already defined/i)
    end

    it "raises ArgumentError when default_page_size is omitted" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page { |collection, number, size| collection }
        end
      end.to raise_error(ArgumentError)
    end
  end

  describe "#apply_pagination!" do
    before { allow(Halitosis.config).to receive(:pagination_adapter).and_return(:kaminari) }

    it "paginates using default_page_size when no page params are given" do
      serializer = klass.new(items)
      context = serializer.send(:build_context, {})
      serializer.send(:apply_pagination!, context)

      expect(context.collection.map { |i| i[:id] }).to eq((1..10).to_a)
      expect(context.query_params[:page]).to eq(number: 1, size: 10)
    end

    it "uses the provided page[number] param" do
      serializer = klass.new(items)
      context = serializer.send(:build_context, {page: {number: 2}})
      serializer.send(:apply_pagination!, context)

      expect(context.collection.map { |i| i[:id] }).to eq((11..20).to_a)
      expect(context.query_params[:page]).to eq(number: 2, size: 10)
    end

    it "uses the provided page[size] param" do
      serializer = klass.new(items)
      context = serializer.send(:build_context, {page: {size: 5}})
      serializer.send(:apply_pagination!, context)

      expect(context.collection.map { |i| i[:id] }).to eq((1..5).to_a)
      expect(context.query_params[:page]).to eq(number: 1, size: 5)
    end

    context "with max_size" do
      let :capped_klass do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page :kaminari, default_page_size: 10, max_size: 20 do |collection, number, size|
            offset = (number - 1) * size
            collection[offset, size] || []
          end
        end
      end

      it "raises InvalidPaginationParameter when the requested size exceeds max_size" do
        serializer = capped_klass.new(items)

        expect do
          serializer.send(:apply_pagination!, serializer.send(:build_context, {page: {size: 100}}))
        end.to raise_error do |exception|
          expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
          expect(exception.message).to match(/must not exceed 20/i)
          expect(exception.parameter).to eq("page[size]")
        end
      end

      it "does not raise when the requested size is exactly max_size" do
        serializer = capped_klass.new(items)
        context = serializer.send(:build_context, {page: {size: 20}})
        serializer.send(:apply_pagination!, context)

        expect(context.query_params[:page]).to eq(number: 1, size: 20)
      end

      it "does not raise when the requested size is within max_size" do
        serializer = capped_klass.new(items)
        context = serializer.send(:build_context, {page: {size: 5}})
        serializer.send(:apply_pagination!, context)

        expect(context.collection.map { |i| i[:id] }).to eq((1..5).to_a)
        expect(context.query_params[:page]).to eq(number: 1, size: 5)
      end

      it "uses the default size when no size param is given and default is within max_size" do
        serializer = capped_klass.new(items)
        context = serializer.send(:build_context, {})
        serializer.send(:apply_pagination!, context)

        expect(context.collection.map { |i| i[:id] }).to eq((1..10).to_a)
        expect(context.query_params[:page]).to eq(number: 1, size: 10)
      end
    end

    it "raises InvalidPaginationParameter when the block returns nil" do
      bad_klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page(default_page_size: 10) { |_collection, _number, _size| nil }
      end

      serializer = bad_klass.new(items)

      expect do
        serializer.send(:apply_pagination!, serializer.send(:build_context, {}))
      end.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(exception.message).to match(/can not be paginated with the provided values/i)
        expect(exception.parameter).to eq("page")
      end
    end

    it "raises InvalidPaginationParameter for an unparseable page[number] value" do
      serializer = klass.new(items)

      expect do
        serializer.send(:apply_pagination!, serializer.send(:build_context, {page: {number: "abc"}}))
      end.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(exception.message).to match(/can not be paginated with the provided 'page\[number\]' value/i)
        expect(exception.parameter).to eq("page[number]")
      end
    end

    it "raises InvalidPaginationParameter for an unparseable page[size] value" do
      serializer = klass.new(items)

      expect do
        serializer.send(:apply_pagination!, serializer.send(:build_context, {page: {size: "abc"}}))
      end.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(exception.message).to match(/can not be paginated with the provided 'page\[size\]' value/i)
        expect(exception.parameter).to eq("page[size]")
      end
    end

    context "when no paginate_by_page is declared" do
      let :unpaginated_klass do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end
        end
      end

      it "does not modify the collection" do
        serializer = unpaginated_klass.new(items)
        context = serializer.send(:build_context, {})
        serializer.send(:apply_pagination!, context)

        expect(context.collection).to eq(items)
      end
    end

    context "when a pagination adapter is configured" do
      let :klass_with_metadata do
        adapter = ->(collection) { {total: collection.size} }

        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page adapter, default_page_size: 10 do |collection, number, size|
            offset = (number - 1) * size
            collection[offset, size] || []
          end
        end
      end

      it "stores the paginated result on the context" do
        serializer = klass_with_metadata.new(items)
        context = serializer.send(:build_context, {page: {number: 2, size: 5}})
        serializer.send(:apply_pagination!, context)

        field = klass_with_metadata.fields.singleton(Halitosis::CollectionPaginatable::Field)
        expect(field.fetch_result(context)).to eq({total: 5})
      end
    end
  end

  describe "#query_params" do
    it "returns page params with defaults when no page is provided" do
      serializer = klass.new(items)
      context = render_context(serializer)

      expect(context.query_params[:page]).to eq(number: 1, size: 10)
    end

    it "reflects the provided page[number]" do
      serializer = klass.new(items, page: {number: 3})
      context = render_context(serializer)

      expect(context.query_params[:page]).to eq(number: 3, size: 10)
    end

    it "reflects the provided page[size]" do
      serializer = klass.new(items, page: {size: 5})
      context = render_context(serializer)

      expect(context.query_params[:page]).to eq(number: 1, size: 5)
    end

    it "reflects both page[number] and page[size]" do
      serializer = klass.new(items, page: {number: 2, size: 20})
      context = render_context(serializer)

      expect(context.query_params[:page]).to eq(number: 2, size: 20)
    end

    it "returns no page key when no paginate_by_page is declared" do
      unpaginated_klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end
      end

      serializer = unpaginated_klass.new(items)
      context = render_context(serializer)

      expect(context.query_params).not_to have_key(:page)
    end
  end

  describe ".paginate_with_pagy" do
    it "stores the pagination procedure without a block" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_with_pagy
      end

      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::Field)).not_to be_nil
    end

    it "raises InvalidField when declared a second time" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_with_pagy
          paginate_with_pagy
        end
      end.to raise_error(Halitosis::InvalidField, /pagination is already defined/i)
    end

    describe "at render time" do
      let(:pagy_obj) { double(page: 2, limit: 15, count: 75, pages: 5, previous: 1, next: 3) }
      let(:records) { [1, 2, 3] }
      let :pagy_klass do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_with_pagy
        end
      end

      before do
        allow(Halitosis::CollectionPaginatable::PagyHelper).to receive(:pagy).and_return([pagy_obj, records])
      end

      it "stores normalized metadata on the context and registers query_params" do
        serializer = pagy_klass.new([1, 2, 3])
        context = serializer.send(:build_context, {page: {number: 2, size: 15}})
        serializer.send(:apply_pagination!, context)

        field = pagy_klass.fields.singleton(Halitosis::CollectionPaginatable::Field)
        expect(field.fetch_result(context)).to eq(
          current_page: 2, total_pages: 5, per_page: 15, total_entries: 75,
          prev_page: 1, next_page: 3
        )
        expect(context.query_params[:page]).to eq(number: 2, size: 15)
      end

      it "calls the block with context, collection, and page_params" do
        kwargs_received = nil

        klass_with_block = Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_with_pagy do |_collection, page_params|
            {limit: page_params[:size].to_i}
          end
        end

        allow(Halitosis::CollectionPaginatable::PagyHelper).to receive(:pagy) do |_col, _params, **kwargs|
          kwargs_received = kwargs
          [pagy_obj, records]
        end

        serializer = klass_with_block.new([1, 2, 3])
        serializer.send(:apply_pagination!, serializer.send(:build_context, {page: {size: "20"}}))

        expect(kwargs_received).to eq(limit: 20)
      end
    end
  end

  describe ".paginate_links" do
    it "registers a PaginationLinksKeyField for each default key" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page(:kaminari, default_page_size: 10) { |collection, number, size| collection }
        paginate_links { |_page_number, _qp| "/items" }
      end

      pagination_link_fields = klass.fields.for_type(Halitosis::RootLinks::Field)
        .select { |f| f.is_a?(Halitosis::CollectionPaginatable::PaginationLinksKeyField) }

      expect(pagination_link_fields.map(&:name))
        .to match_array(Halitosis::CollectionPaginatable::PaginationLinksKeyField::DEFAULT_KEYS)
    end

    it "stores the resolved adapter on the Field" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page(:will_paginate, default_page_size: 10) { |collection, number, size| collection }
        paginate_links { |_page_number, _qp| "/items" }
      end

      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::Field).options[:adapter])
        .to eq(Halitosis::CollectionPaginatable::Adapters::WillPaginate)
    end

    it "falls back to the global config adapter when none is passed" do
      allow(Halitosis).to receive(:config).and_return(
        instance_double(Halitosis::Configuration, pagination_adapter: :kaminari, extensions: [], collect_includes: false)
      )

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
        paginate_links { |_page_number, _qp| "/items" }
      end

      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::Field).options[:adapter])
        .to eq(Halitosis::CollectionPaginatable::Adapters::Kaminari)
    end

    it "raises InvalidField without a block" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page(:kaminari, default_page_size: 10) { |collection, number, size| collection }
          paginate_links
        end
      end.to raise_error(Halitosis::InvalidField, /paginate_links must be defined with a block/i)
    end

    it "raises InvalidField when the block does not accept exactly 2 arguments" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page(:kaminari, default_page_size: 10) { |collection, number, size| collection }
          paginate_links { |page_number| "/items" }
        end
      end.to raise_error(Halitosis::InvalidField, /must accept exactly 2 arguments/i)
    end

    it "raises InvalidField when no adapter is configured and none is passed" do
      allow(Halitosis.config).to receive(:pagination_adapter).and_return(nil)

      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
          paginate_links { |_page_number, _qp| "/items" }
        end
      end.to raise_error(Halitosis::InvalidField, /requires an adapter/i)
    end
  end

  describe ".paginate_meta" do
    it "registers a PaginationMetaKeyField for each default key" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page :kaminari, default_page_size: 10 do |collection, number, size|
          offset = (number - 1) * size
          collection[offset, size] || []
        end

        paginate_meta
      end

      key_fields = klass.fields.for_type(Halitosis::RootMeta::Field)
        .select { |f| f.is_a?(Halitosis::CollectionPaginatable::PaginationMetaKeyField) }

      expect(key_fields.map(&:name)).to match_array(Halitosis::CollectionPaginatable::PaginationMetaKeyField::DEFAULT_KEYS)
    end

    it "raises InvalidField when declared before pagination is set up" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_meta
        end
      end.to raise_error(Halitosis::InvalidField, /must be declared after/i)
    end
  end
end
