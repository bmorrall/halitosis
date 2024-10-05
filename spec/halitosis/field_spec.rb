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
      context = Halitosis::Context.new(nil)

      expect(field.value(context)).to eq("some value")
    end

    it "evaluates procedure if value from options is missing" do
      field = described_class.new(:name, {}, proc { size })
      context = Halitosis::Context.new("foo")

      expect(field.value(context)).to eq(3)
    end
  end

  describe "#enabled?" do
    it "is true if field is not guarded" do
      field = described_class.new(:name, {}, nil)

      context = Halitosis::Context.new(nil)
      expect(field.enabled?(context)).to be(true)
    end

    describe "when guard is a proc" do
      let :field do
        described_class.new(:name, {if: proc { empty? }}, nil)
      end

      it "is true if condition passes" do
        context = Halitosis::Context.new("")
        expect(field.enabled?(context)).to be(true)
      end

      it "is false if condition fails" do
        context = Halitosis::Context.new("foo")
        expect(field.enabled?(context)).to be(false)
      end
    end

    describe "when guard is a method name" do
      let :field do
        described_class.new(:name, {if: :empty?}, nil)
      end

      it "is true if condition passes" do
        context = Halitosis::Context.new("")
        expect(field.enabled?(context)).to be(true)
      end

      it "is false if condition fails" do
        context = Halitosis::Context.new("foo")
        expect(field.enabled?(context)).to be(false)
      end
    end

    describe "when guard is truthy" do
      it "is true if condition passes" do
        field = described_class.new(:name, {if: true}, nil)

        context = Halitosis::Context.new(nil)
        expect(field.enabled?(context)).to be(true)
      end

      it "is false if condition fails" do
        field = described_class.new(:name, {if: false}, nil)

        context = Halitosis::Context.new(nil)
        expect(field.enabled?(context)).to be(false)
      end
    end

    describe "when guard is negated" do
      let :field do
        described_class.new(:name, {unless: proc { empty? }}, nil)
      end

      it "is false if condition passes" do
        context = Halitosis::Context.new("")
        expect(field.enabled?(context)).to be(false)
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
