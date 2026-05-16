# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::LinksField do
  describe "#validate" do
    it "raises InvalidField when no procedure is given" do
      field = described_class.new(:pagination_links, {}, nil)

      expect { field.validate }.to raise_error(
        Halitosis::InvalidField,
        "Pagination links pagination_links must be defined with a proc"
      )
    end

    it "returns true when a procedure is given" do
      field = described_class.new(:pagination_links, {}, ->(_page, _qp) { "/items" })

      expect(field.validate).to be true
    end
  end
end
