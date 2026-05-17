# frozen_string_literal: true

RSpec.describe Halitosis::Fields do
  subject :fields do
    described_class.new
  end

  let :field do
    Halitosis::Field.new(:name, {}, nil)
  end

  describe "#add" do
    it "validates and adds field" do
      expect(fields.keys).to eq([])

      fields.add(field)

      expect(fields.keys).to eq(["Halitosis::Field"])
      expect(fields["Halitosis::Field"]).to eq([field])
    end
  end

  describe "#for_type" do
    it "returns fields for the given type" do
      fields.add(field)

      expect(fields.for_type(Halitosis::Field)).to eq([field])
    end

    it "returns empty array when no fields of the given type exist" do
      expect(fields.for_type(Halitosis::Field)).to eq([])
    end
  end

  describe "#add_singleton" do
    it "validates and stores the field" do
      fields.add_singleton(field)

      expect(fields[field.class.name]).to eq(field)
    end

    it "raises InvalidField if a singleton of the same type is already registered" do
      fields.add_singleton(field)

      other_field = Halitosis::Field.new(:other, {}, nil)

      expect { fields.add_singleton(other_field) }.to raise_error(
        Halitosis::InvalidField, "Halitosis::Field is already defined"
      )
    end

    it "raises InvalidField if the type was already registered via add" do
      fields.add(field)

      expect { fields.add_singleton(field) }.to raise_error(
        Halitosis::InvalidField, "Halitosis::Field is already defined"
      )
    end
  end

  describe "#singleton" do
    it "returns the registered singleton field for the given type" do
      fields.add_singleton(field)

      expect(fields.singleton(Halitosis::Field)).to eq(field)
    end

    it "returns nil when no singleton field has been registered for the type" do
      expect(fields.singleton(Halitosis::Field)).to be_nil
    end
  end
end
