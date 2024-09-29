# frozen_string_literal: true

RSpec.describe Halitosis::Field do
  describe "#initialize" do
    it "symbolizes option keys" do
      field = described_class.new(
        :name, {"value" => "some value", "foo" => "bar"}, nil
      )

      expect(field.options.keys).to eq(%i[value foo])
    end
  end

  describe "#value" do
    it "returns value from options if present" do
      field = described_class.new(:name, {value: "some value"}, nil)

      expect(field.value(nil)).to eq("some value")
    end

    it "evaluates procedure if value from options is missing" do
      field = described_class.new(:name, {}, proc { size })

      expect(field.value("foo")).to eq(3)
    end
  end

  describe "#enabled?" do
    it "is true if field is not guarded" do
      field = described_class.new(:name, {}, nil)

      expect(field.enabled?(nil)).to eq(true)
    end

    describe "when guard is a proc" do
      let :field do
        described_class.new(:name, {if: proc { empty? }}, nil)
      end

      it "is true if condition passes" do
        expect(field.enabled?("")).to eq(true)
      end

      it "is false if condition fails" do
        expect(field.enabled?("foo")).to eq(false)
      end
    end

    describe "when guard is a method name" do
      let :field do
        described_class.new(:name, {if: :empty?}, nil)
      end

      it "is true if condition passes" do
        expect(field.enabled?("")).to eq(true)
      end

      it "is false if condition fails" do
        expect(field.enabled?("foo")).to eq(false)
      end
    end

    describe "when guard is truthy" do
      it "is true if condition passes" do
        field = described_class.new(:name, {if: true}, nil)

        expect(field.enabled?(nil)).to eq(true)
      end

      it "is false if condition fails" do
        field = described_class.new(:name, {if: false}, nil)

        expect(field.enabled?(nil)).to eq(false)
      end
    end

    describe "when guard is negated" do
      let :field do
        described_class.new(:name, {unless: proc { empty? }}, nil)
      end

      it "is false if condition passes" do
        expect(field.enabled?("")).to eq(false)
      end
    end
  end

  describe "#validate" do
    it "returns true for valid field" do
      field = described_class.new(:name, {value: "value"}, nil)

      expect(field.validate).to eq(true)
    end

    it "raises error for invalid field" do
      field = described_class.new(
        :name, {value: "value"}, proc { "value" }
      )

      expect do
        field.validate
      end.to raise_error(Halitosis::InvalidField) do |exception|
        expect(exception.message).to(
          eq("Cannot specify both value and procedure for name")
        )
      end
    end
  end
end
