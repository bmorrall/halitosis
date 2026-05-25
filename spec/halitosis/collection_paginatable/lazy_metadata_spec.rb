# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::LazyMetadata do
  subject(:metadata) { described_class.new(source, definitions) }

  let(:source) { double(:source) } # rubocop:disable RSpec/VerifiedDoubles
  let(:called) { [] }

  let(:definitions) do
    {
      current_page: ->(s) {
        called << :current_page
        s.current_page
      },
      total_pages: ->(s) {
        called << :total_pages
        s.total_pages
      },
      total_entries: ->(s) {
        called << :total_entries
        s.total_entries
      }
    }
  end

  describe "#[]" do
    it "returns the value for a defined key" do
      allow(source).to receive(:current_page).and_return(2)

      expect(metadata[:current_page]).to eq(2)
    end

    it "returns nil for an undefined key" do
      expect(metadata[:unknown]).to be_nil
    end

    it "does not call the definition until the key is accessed" do
      allow(source).to receive_messages(current_page: 2, total_entries: 100)

      metadata[:current_page]

      expect(source).not_to have_received(:total_entries)
      expect(called).to eq([:current_page])
    end

    it "memoizes the result so the definition is only called once" do
      allow(source).to receive(:current_page).and_return(3)

      metadata[:current_page]
      metadata[:current_page]

      expect(source).to have_received(:current_page).once
    end

    it "evaluates each key independently" do
      allow(source).to receive_messages(current_page: 1, total_pages: 5)

      metadata[:current_page]

      expect(called).to eq([:current_page])
      expect(source).not_to have_received(:total_pages)

      metadata[:total_pages]

      expect(called).to eq([:current_page, :total_pages])
    end
  end

  describe "#key?" do
    it "returns true for a defined key" do
      expect(metadata.key?(:current_page)).to be true
    end

    it "returns false for an undefined key" do
      expect(metadata.key?(:unknown)).to be false
    end
  end

  describe "#to_h" do
    it "materialises all values into a plain Hash" do
      allow(source).to receive_messages(current_page: 2, total_pages: 10, total_entries: 100)

      expect(metadata.to_h).to eq(current_page: 2, total_pages: 10, total_entries: 100)
    end
  end

  describe "#==" do
    it "equals a Hash with the same materialised values" do
      allow(source).to receive_messages(current_page: 2, total_pages: 10, total_entries: 100)

      expect(metadata).to eq(current_page: 2, total_pages: 10, total_entries: 100)
    end

    it "equals another LazyMetadata with the same values" do
      allow(source).to receive_messages(current_page: 2, total_pages: 10, total_entries: 100)

      other_source = double(current_page: 2, total_pages: 10, total_entries: 100) # rubocop:disable RSpec/VerifiedDoubles
      other = described_class.new(other_source, definitions)

      expect(metadata).to eq(other)
    end

    it "does not equal an unrelated object" do
      expect(metadata).not_to eq("not metadata")
    end
  end
end
