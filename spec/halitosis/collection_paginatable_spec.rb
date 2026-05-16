# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable do
  let :klass do
    Class.new do
      include Halitosis

      collection :items do |collection|
        collection
      end

      paginate_by_page default_page_size: 10 do |collection, number, size|
        offset = (number - 1) * size
        collection[offset, size] || []
      end
    end
  end

  let(:items) { (1..50).map { |i| {id: i} } }

  describe ".paginate_with" do
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
    it "stores the pagination procedure" do
      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::Field)).not_to be_nil
    end

    it "raises InvalidField without a block" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page default_page_size: 10
        end
      end.to raise_error(Halitosis::InvalidField, /paginate_by_page must be defined with a block/i)
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
        expect(exception.parameter).to eq("page")
      end
    end

    it "raises InvalidPaginationParameter for an unparseable page[size] value" do
      serializer = klass.new(items)

      expect do
        serializer.send(:apply_pagination!, serializer.send(:build_context, {page: {size: "abc"}}))
      end.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(exception.message).to match(/can not be paginated with the provided 'page\[size\]' value/i)
        expect(exception.parameter).to eq("page")
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

    context "when a MetadataField singleton is registered" do
      let :klass_with_metadata do
        adapter = ->(collection) { {total: collection.size} }

        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page default_page_size: 10 do |collection, number, size|
            offset = (number - 1) * size
            collection[offset, size] || []
          end

          fields.add_singleton(Halitosis::CollectionPaginatable::MetadataField.new(adapter))
        end
      end

      it "stores the paginated result on the context via the MetadataField" do
        serializer = klass_with_metadata.new(items)
        context = serializer.send(:build_context, {page: {number: 2, size: 5}})
        serializer.send(:apply_pagination!, context)

        metadata_field = klass_with_metadata.fields.singleton(Halitosis::CollectionPaginatable::MetadataField)
        expect(metadata_field.fetch_result(context)).to eq({total: 5})
      end
    end
  end

  describe "#query_params" do
    it "returns page params with defaults when no page is provided" do
      serializer = klass.new(items)
      context = serializer.send(:build_context)
      serializer.send(:render_with_context, context)

      expect(context.query_params[:page]).to eq(number: 1, size: 10)
    end

    it "reflects the provided page[number]" do
      serializer = klass.new(items, page: {number: 3})
      context = serializer.send(:build_context)
      serializer.send(:render_with_context, context)

      expect(context.query_params[:page]).to eq(number: 3, size: 10)
    end

    it "reflects the provided page[size]" do
      serializer = klass.new(items, page: {size: 5})
      context = serializer.send(:build_context)
      serializer.send(:render_with_context, context)

      expect(context.query_params[:page]).to eq(number: 1, size: 5)
    end

    it "reflects both page[number] and page[size]" do
      serializer = klass.new(items, page: {number: 2, size: 20})
      context = serializer.send(:build_context)
      serializer.send(:render_with_context, context)

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
      context = serializer.send(:build_context)
      serializer.send(:render_with_context, context)

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
      let(:pagy_obj) { double(page: 2, limit: 15, pages: 5, previous: 1, next: 3) }
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

        metadata_field = pagy_klass.fields.singleton(Halitosis::CollectionPaginatable::MetadataField)
        expect(metadata_field.fetch_result(context)).to eq(
          current_page: 2, total_pages: 5, prev_page: 1, next_page: 3
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
    it "stores a LinksField singleton" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
        paginate_links(:kaminari) { |_page_number, _qp| "/items" }
      end

      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::LinksField)).not_to be_nil
    end

    it "stores the adapter in a MetadataField" do
      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
        paginate_links(:will_paginate) { |_page_number, _qp| "/items" }
      end

      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::MetadataField).adapter)
        .to eq(Halitosis::CollectionPaginatable::Adapters::WillPaginate)
    end

    it "falls back to the global config adapter when none is passed" do
      allow(Halitosis).to receive(:config).and_return(
        instance_double(Halitosis::Configuration, pagination_adapter: :kaminari, extensions: [])
      )

      klass = Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
        paginate_links { |_page_number, _qp| "/items" }
      end

      expect(klass.fields.singleton(Halitosis::CollectionPaginatable::MetadataField).adapter)
        .to eq(Halitosis::CollectionPaginatable::Adapters::Kaminari)
    end

    it "raises InvalidField without a block" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
          paginate_links :kaminari
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

          paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
          paginate_links(:kaminari) { |page_number| "/items" }
        end
      end.to raise_error(Halitosis::InvalidField, /must accept exactly 2 arguments/i)
    end

    it "raises InvalidField when declared a second time" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_page(default_page_size: 10) { |collection, number, size| collection }
          paginate_links(:kaminari) { |_page_number, _qp| "/items" }
          paginate_links(:kaminari) { |_page_number, _qp| "/items" }
        end
      end.to raise_error(Halitosis::InvalidField, /pagination links are already defined/i)
    end

    it "raises InvalidField when an adapter is given alongside paginate_with_pagy" do
      expect do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_with_pagy
          paginate_links(:kaminari) { |_page_number, _qp| "/items" }
        end
      end.to raise_error(Halitosis::InvalidField, /adapter must not be set when using paginate_with_pagy/i)
    end

    it "raises InvalidField when no adapter is configured and none is passed" do
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
end
