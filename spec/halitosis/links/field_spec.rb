# frozen_string_literal: true

RSpec.describe Halitosis::Links::Field do
  describe "#validate" do
    it "returns true with procedure" do
      result = described_class.new(:name, proc {}).validate

      expect(result).to eq(true)
    end

    it "raises exception without procedure or explicit value" do
      expect do
        described_class.new(:name, nil).validate
      end.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidField)
        expect(exception.message).to(
          eq("Link name requires either procedure or explicit value")
        )
      end
    end
  end

  describe "#value" do
    it "handles multiple hrefs" do
      field = described_class.new(
        :name, proc { %w[first second] }
      )

      expect(field.value(nil)).to eq([
        {href: "first"},
        {href: "second"}
      ])
    end

    it "handles multiple hrefs with additional attributes" do
      field = described_class.new(
        :name, {attrs: {foo: "bar"}}, proc { %w[first second] }
      )

      expect(field.value(nil)).to eq([
        {href: "first", foo: "bar"},
        {href: "second", foo: "bar"}
      ])
    end

    it "handles single href" do
      field = described_class.new(:name, proc { "first" })

      expect(field.value(nil)).to eq(href: "first")
    end

    it "is nil for nil href" do
      field = described_class.new(:name, proc {})

      expect(field.value(nil)).to be_nil
    end
  end

  describe ".build_options" do
    it "has expected value without options hash" do
      options = described_class.build_options([])

      expect(options).to eq(attrs: {})
    end

    it "has expected value with options hash" do
      options = described_class.build_options([foo: "bar"])

      expect(options).to eq(attrs: {}, foo: "bar")
    end

    it "merges attrs from options" do
      options = described_class.build_options([
        :templated,
        {attrs: {attributes: {}},
         foo: "bar"}
      ])

      expect(options).to(
        eq(attrs: {attributes: {}, templated: true}, foo: "bar")
      )
    end
  end

  describe ".build_attrs" do
    it "returns empty hash if no keywords are provided" do
      expect(described_class.build_attrs([])).to eq({})
    end

    it "builds expected hash with recognized keywords" do
      attrs = described_class.build_attrs([:templated])

      expect(attrs).to eq(templated: true)
    end

    it "raises exception if unrecognized keyword is included" do
      expect do
        described_class.build_attrs(%i[templated wat])
      end.to raise_error do |exception|
        expect(exception.class).to eq(Halitosis::InvalidField)
        expect(exception.message).to eq("Unrecognized link keyword: wat")
      end
    end
  end
end
