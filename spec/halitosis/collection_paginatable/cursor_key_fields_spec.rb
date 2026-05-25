# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::CursorLinksKeyField do
  describe ".registerable_as" do
    it "returns RootLinks::Field so instances are stored in the root_links bucket" do
      expect(described_class.registerable_as).to eq(Halitosis::RootLinks::Field)
    end
  end

  describe "#always_emit?" do
    it "returns true so nil values are still emitted in _links" do
      cursor_field = instance_double(Halitosis::CollectionPaginatable::CursorField)
      field = described_class.new(:next, cursor_field, ->(_cursor, _qp) {})

      expect(field.always_emit?).to be true
    end
  end

  describe "#validate" do
    it "returns true" do
      cursor_field = instance_double(Halitosis::CollectionPaginatable::CursorField)
      field = described_class.new(:next, cursor_field, ->(_cursor, _qp) { "/items" })

      expect(field.validate).to be true
    end
  end
end

RSpec.describe Halitosis::CollectionPaginatable::CursorMetaKeyField do
  describe ".registerable_as" do
    it "returns RootMeta::Field so instances are stored in the root_meta bucket" do
      expect(described_class.registerable_as).to eq(Halitosis::RootMeta::Field)
    end
  end

  describe "#validate" do
    it "returns true" do
      cursor_field = instance_double(Halitosis::CollectionPaginatable::CursorField)
      field = described_class.new(:next_cursor, cursor_field)

      expect(field.validate).to be true
    end
  end
end
