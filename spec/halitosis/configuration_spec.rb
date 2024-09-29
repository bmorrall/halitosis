RSpec.describe Halitosis::Configuration do
  describe "#extensions" do
    it "is empty array by default" do
      expect(described_class.new.extensions).to eq([])
    end
  end
end
