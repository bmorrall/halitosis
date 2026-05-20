# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::PaginationLinksKeyField do
  describe ".registerable_as" do
    it "returns RootLinks::Field so instances are stored in the root_links bucket" do
      expect(described_class.registerable_as).to eq(Halitosis::RootLinks::Field)
    end
  end

  describe "#always_emit?" do
    it "returns true so nil values are still emitted in _links" do
      pagination_field = instance_double(Halitosis::CollectionPaginatable::Field)
      field = described_class.new(:prev, pagination_field, ->(_n, _qp) {})

      expect(field.always_emit?).to be true
    end
  end

  describe "#validate" do
    it "returns true (validation is performed by paginate_links at DSL time)" do
      pagination_field = instance_double(Halitosis::CollectionPaginatable::Field)
      field = described_class.new(:self, pagination_field, ->(_n, _qp) { "/items" })

      expect(field.validate).to be true
    end
  end
end
