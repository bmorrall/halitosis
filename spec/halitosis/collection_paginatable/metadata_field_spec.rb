# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::MetadataField do
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
  let(:adapter) { ->(raw) { {current_page: 1, total_pages: 3, prev_page: nil, next_page: 2} } }
  let(:field) { described_class.new(adapter) }
  let(:context) { klass.new(items).send(:build_context, {}) }

  describe "#metadata" do
    it "returns the stored result after process" do
      field.process(context, double)

      expect(field.metadata(context)).to eq(
        current_page: 1, total_pages: 3, prev_page: nil, next_page: 2
      )
    end
  end

  describe "#page_numbers" do
    it "returns a nav hash derived from metadata" do
      field.process(context, double)

      expect(field.page_numbers(context)).to eq(
        first: 1, last: 3, prev: nil, next: 2
      )
    end

    it "returns nil when no metadata has been stored" do
      expect(field.page_numbers(context)).to be_nil
    end
  end

  describe "#validate" do
    it "raises InvalidField when the adapter is not callable" do
      bad_field = described_class.new("not_callable")

      expect { bad_field.validate }
        .to raise_error(Halitosis::InvalidField, /adapter must be callable/i)
    end
  end
end
