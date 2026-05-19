# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::Field do
  before { allow(Halitosis.config).to receive(:pagination_adapter).and_return(:kaminari) }

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
  let(:adapter) { ->(raw) { {current_page: 1, total_pages: 3, per_page: 10, total_entries: 30, prev_page: nil, next_page: 2} } }
  let(:field) { described_class.new(:pagination, {adapter: adapter}, ->(_c, col, _page) { col }) }
  let(:context) { klass.new(items).send(:build_context, {}) }

  describe "#metadata" do
    it "returns the stored result after process" do
      field.process(context, double)

      expect(field.metadata(context)).to eq(
        current_page: 1, total_pages: 3, per_page: 10, total_entries: 30, prev_page: nil, next_page: 2
      )
    end
  end

  describe "#collection_meta" do
    it "returns {current_page:, per_page:, total_entries:, total_pages:}" do
      field.process(context, double)

      expect(field.collection_meta(context)).to eq(
        current_page: 1, per_page: 10, total_entries: 30, total_pages: 3
      )
    end

    it "returns nil when no metadata has been stored" do
      expect(field.collection_meta(context)).to be_nil
    end
  end

  describe "#page_numbers" do
    it "returns a nav hash derived from metadata" do
      field.process(context, double)

      expect(field.page_numbers(context)).to eq(
        self: 1, first: 1, last: 3, prev: nil, next: 2
      )
    end

    it "returns nil when no metadata has been stored" do
      expect(field.page_numbers(context)).to be_nil
    end
  end

  describe "#validate" do
    it "raises InvalidField when no procedure is set" do
      bad_field = described_class.new(:pagination, {adapter: -> {}}, nil)

      expect { bad_field.validate }
        .to raise_error(Halitosis::InvalidField, /must be defined with a proc/i)
    end

    it "raises InvalidField when the adapter is not callable" do
      bad_field = described_class.new(:pagination, {adapter: "not_callable"}, ->(_c, col, _page) { col })

      expect { bad_field.validate }
        .to raise_error(Halitosis::InvalidField, /adapter must be callable/i)
    end
  end
end
