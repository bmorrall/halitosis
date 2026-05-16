# frozen_string_literal: true

RSpec.describe Halitosis do
  it "has a version number" do
    expect(Halitosis::VERSION).not_to be_nil
  end

  describe Halitosis::ClassMethods do
    describe "#resource" do
      it "includes resource module" do
        klass = Class.new { include Halitosis }

        expect(klass).to receive(:define_resource).with(:foo)

        klass.resource :foo

        expect(klass.include?(Halitosis::Resource)).to be(true)
      end
    end

    describe "#collection" do
      it "includes collection module", :aggregate_failures do
        klass = Class.new { include Halitosis }

        expect(klass).to receive(:define_collection).with(:foo)

        klass.collection :foo do
          -> { [] }
        end

        expect(klass.include?(Halitosis::Collection)).to be(true)
      end
    end

    describe "#collection?" do
      it "is false by default" do
        klass = Class.new { include Halitosis }

        expect(klass.collection?).to be(false)
      end

      it "is true for collection" do
        klass = Class.new { include Halitosis }

        klass.collection :foo do
          -> { [] }
        end

        expect(klass.collection?).to be(true)
      end
    end
  end

  describe ".configure" do
    it "yields configuration instance" do
      described_class.configure do |config|
        expect(config).to eq(described_class.config)
      end
    end
  end
end
