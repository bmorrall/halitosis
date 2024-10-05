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
      Class.new {
        include Halitosis::Base
        include Halitosis::Relationships
      }
    end

    [1, 2, true, "1", "2", "true", "yes"].each do |value|
      it "is true for expected values #{value.inspect}" do
        context = klass.new(include: {foo: value}).send(:build_context)

        relationship = described_class.new(:foo, {}, proc {})

        expect(relationship.send(:enabled?, context)).to be(true)
      end
    end

    [0, false, "0", "false"].each do |value|
      it "is false for expected values #{value.inspect}" do
        context = klass.new(include: {foo: value}).send(:build_context)

        relationship = described_class.new(:foo, {}, proc {})

        expect(relationship.send(:enabled?, context)).to be(false)
      end
    end

    it "is false by default" do
      context = klass.new.send(:build_context)

      relationship = described_class.new(:foo, {}, proc {})

      expect(relationship.send(:enabled?, context)).to be(false)
    end
  end
end
