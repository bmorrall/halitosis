# frozen_string_literal: true

RSpec.describe Halitosis::ResourceIncludes::Field do
  describe "#initialize" do
    it "stores name as a symbol" do
      field = described_class.new("accounts", nil, [])

      expect(field.name).to eq(:accounts)
    end

    it "stores nil when no procedure is given" do
      field = described_class.new(:accounts, nil, [])

      expect(field.procedure).to be_nil
    end

    it "uses the given procedure when provided" do
      proc = ->(v) { v.upcase }
      field = described_class.new(:accounts, proc, [])

      expect(field.procedure).to eq(proc)
    end

    it "stores children" do
      child = described_class.new(:owner, nil, [])
      field = described_class.new(:accounts, nil, [child])

      expect(field.children).to contain_exactly(child)
    end

    it "freezes the children array" do
      field = described_class.new(:accounts, nil, [])

      expect(field.children).to be_frozen
    end

    it "does not freeze the original children array passed in" do
      original = []
      described_class.new(:accounts, nil, original)

      expect(original).not_to be_frozen
    end
  end

  describe "#validate" do
    it "returns true" do
      field = described_class.new(:accounts, nil, [])

      expect(field.validate).to be(true)
    end
  end

  describe "DEFAULT_PROCEDURE" do
    it "returns the value unchanged" do
      value = Object.new

      expect(described_class::DEFAULT_PROCEDURE.call(value)).to equal(value)
    end
  end
end
