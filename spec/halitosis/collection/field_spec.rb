RSpec.describe Halitosis::Collection::Field do
  describe "#validate" do
    it "returns true with procedure" do
      result = described_class.new(:name, {}, proc {}).validate

      expect(result).to eq(true)
    end

    it "raises exception without procedure" do
      expect {
        described_class.new(:name, {}, nil).validate
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidField)
        expect(exception.message).to(
          eq("Collection name must be defined with a proc")
        )
      end
    end
  end
end
