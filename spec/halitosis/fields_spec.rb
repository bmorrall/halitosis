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
end
