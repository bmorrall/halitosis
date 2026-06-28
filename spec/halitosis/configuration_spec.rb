RSpec.describe Halitosis::Configuration do
  describe "#extensions" do
    it "is empty array by default" do
      expect(described_class.new.extensions).to eq([])
    end
  end

  describe "#allow_undeclared_includes" do
    it "is true by default" do
      expect(described_class.new.allow_undeclared_includes).to be true
    end

    it "can be set to false" do
      config = described_class.new
      config.allow_undeclared_includes = false
      expect(config.allow_undeclared_includes).to be false
    end
  end
end
