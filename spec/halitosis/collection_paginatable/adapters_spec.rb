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

    it "returns a normalized metadata hash for a Kaminari-paginated collection" do
      collection = double(
        current_page: 2, total_pages: 5,
        prev_page: 1, next_page: 3,
        limit_value: 25, total_count: 100
      )
      allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_pages).and_return(true)
      allow(collection).to receive(:respond_to?).with(:limit_value).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_count).and_return(true)

      expect(adapter.call(collection)).to eq(
        current_page: 2, total_pages: 5, per_page: 25, total_entries: 100,
        prev_page: 1, next_page: 3
      )
    end
  end

  describe "WillPaginate" do
    subject(:adapter) { described_class::WillPaginate }

    it "returns nil when the collection does not respond to :current_page" do
      expect(adapter.call([])).to be_nil
    end

    it "returns a normalized metadata hash for a WillPaginate-paginated collection" do
      collection = double(
        current_page: 3, total_pages: 10,
        previous_page: 2, next_page: 4,
        per_page: 20, total_entries: 200
      )
      allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_pages).and_return(true)
      allow(collection).to receive(:respond_to?).with(:per_page).and_return(true)
      allow(collection).to receive(:respond_to?).with(:total_entries).and_return(true)

      expect(adapter.call(collection)).to eq(
        current_page: 3, total_pages: 10, per_page: 20, total_entries: 200,
        prev_page: 2, next_page: 4
      )
    end
  end

  describe "Pagy" do
    subject(:adapter) { described_class::Pagy }

    it "returns nil when called with nil" do
      expect(adapter.call(nil)).to be_nil
    end
  end
end
