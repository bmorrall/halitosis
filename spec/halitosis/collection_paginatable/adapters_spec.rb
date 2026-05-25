# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::Adapters do
  describe ".resolve" do
    it "returns the Kaminari adapter for :kaminari" do
      expect(described_class.resolve(:kaminari))
        .to eq(described_class::Kaminari)
    end

    it "returns the WillPaginate adapter for :will_paginate" do
      expect(described_class.resolve(:will_paginate))
        .to eq(described_class::WillPaginate)
    end

    it "returns a callable directly without wrapping it" do
      my_adapter = -> {}

      expect(described_class.resolve(my_adapter)).to eq(my_adapter)
    end

    it "raises InvalidField for an unknown symbol" do
      expect { described_class.resolve(:unknown) }
        .to raise_error(Halitosis::InvalidField, /unknown pagination adapter/i)
    end
  end

  describe "Kaminari" do
    subject(:adapter) { described_class::Kaminari }

    it "returns nil when the collection does not respond to :current_page" do
      expect(adapter.call([])).to be_nil
    end

    it "returns a LazyMetadata wrapper for a Kaminari-paginated collection" do
      collection = double(
        current_page: 2, total_pages: 5,
        prev_page: 1, next_page: 3,
        limit_value: 25, total_count: 100
      )
      allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_pages).and_return(true)
      allow(collection).to receive(:respond_to?).with(:limit_value).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_count).and_return(true)

      result = adapter.call(collection)

      expect(result).to be_a(Halitosis::CollectionPaginatable::LazyMetadata)
      expect(result[:current_page]).to eq(2)
      expect(result[:total_pages]).to eq(5)
      expect(result[:per_page]).to eq(25)
      expect(result[:total_entries]).to eq(100)
      expect(result[:prev_page]).to eq(1)
      expect(result[:next_page]).to eq(3)
    end

    it "does not access total_count until [:total_entries] is read" do
      collection = double(current_page: 1, total_pages: 3, prev_page: nil, next_page: 2)
      allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_pages).and_return(true)
      allow(collection).to receive(:respond_to?).with(:limit_value).and_return(false)
      allow(collection).to receive(:respond_to?).with(:total_count).and_return(true)
      allow(collection).to receive(:total_count).and_return(999)

      result = adapter.call(collection)

      # Force navigation-only keys
      result[:current_page]
      result[:total_pages]
      result[:prev_page]
      result[:next_page]

      expect(collection).not_to have_received(:total_count)
    end

    describe ".default_per_page_procedure" do
      it "returns a callable that paginates the collection" do
        collection = double
        paged = double
        allow(collection).to receive(:page).with(1).and_return(paged)
        allow(paged).to receive(:per).with(25).and_return(:result)

        result = adapter.default_per_page_procedure.call(collection, 1, 25)

        expect(result).to eq(:result)
      end
    end
  end

  describe "WillPaginate" do
    subject(:adapter) { described_class::WillPaginate }

    it "returns nil when the collection does not respond to :current_page" do
      expect(adapter.call([])).to be_nil
    end

    it "returns a LazyMetadata wrapper for a WillPaginate-paginated collection" do
      collection = double(
        current_page: 3, total_pages: 10,
        previous_page: 2, next_page: 4,
        per_page: 20, total_entries: 200
      )
      allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_pages).and_return(true)
      allow(collection).to receive(:respond_to?).with(:per_page).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_entries).and_return(true)

      result = adapter.call(collection)

      expect(result).to be_a(Halitosis::CollectionPaginatable::LazyMetadata)
      expect(result[:current_page]).to eq(3)
      expect(result[:total_pages]).to eq(10)
      expect(result[:per_page]).to eq(20)
      expect(result[:total_entries]).to eq(200)
      expect(result[:prev_page]).to eq(2)
      expect(result[:next_page]).to eq(4)
    end

    it "does not access total_entries until [:total_entries] is read" do
      collection = double(current_page: 1, total_pages: 3, previous_page: nil, next_page: 2)
      allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_pages).and_return(true)
      allow(collection).to receive(:respond_to?).with(:per_page).and_return(false)
      allow(collection).to receive(:respond_to?).with(:total_entries).and_return(true)
      allow(collection).to receive(:total_entries).and_return(999)

      result = adapter.call(collection)

      # Force navigation-only keys
      result[:current_page]
      result[:total_pages]
      result[:prev_page]
      result[:next_page]

      expect(collection).not_to have_received(:total_entries)
    end

    describe ".default_per_page_procedure" do
      it "returns a callable that paginates the collection" do
        collection = double
        allow(collection).to receive(:paginate).with(page: 2, per_page: 10).and_return(:result)

        result = adapter.default_per_page_procedure.call(collection, 2, 10)

        expect(result).to eq(:result)
      end
    end
  end

  describe "Pagy" do
    subject(:adapter) { described_class::Pagy }

    it "returns nil when called with nil" do
      expect(adapter.call(nil)).to be_nil
    end

    it "returns a LazyMetadata wrapper for a Pagy object" do
      pagy = double(page: 2, pages: 5, limit: 10, count: 50, previous: 1, next: 3)

      result = adapter.call(pagy)

      expect(result).to be_a(Halitosis::CollectionPaginatable::LazyMetadata)
      expect(result[:current_page]).to eq(2)
      expect(result[:total_pages]).to eq(5)
      expect(result[:per_page]).to eq(10)
      expect(result[:total_entries]).to eq(50)
      expect(result[:prev_page]).to eq(1)
      expect(result[:next_page]).to eq(3)
    end
  end
end
