RSpec.describe Halitosis::Relationships::Field do
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
          eq("Relationship name must be defined with a proc")
        )
      end
    end
  end

  describe "#enabled?" do
    let :klass do
      Class.new { include Halitosis }
    end

    it "is true for expected values" do
      [1, 2, true, "1", "2", "true", "yes"].each do |value|
        serializer = klass.new(include: {foo: value})

        relationship = described_class.new(:foo, {}, proc {})

        expect(relationship.send(:enabled?, serializer)).to eq(true)
      end
    end

    it "is false for expected values" do
      [0, false, "0", "false"].each do |value|
        serializer = klass.new(include: {foo: value})

        relationship = described_class.new(:foo, {}, proc {})

        expect(relationship.send(:enabled?, serializer)).to eq(false)
      end
    end

    it "is false by default" do
      serializer = klass.new

      relationship = described_class.new(:foo, {}, proc {})

      expect(relationship.send(:enabled?, serializer)).to eq(false)
    end
  end
end
