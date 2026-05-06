# frozen_string_literal: true

RSpec.describe Halitosis::HashUtil do
  describe ".hasherize_include_option" do
    it "stringifies hash keys" do
      expect(described_class.hasherize_include_option({foo: {bar: 1}})).to eq("foo" => {bar: 1})
    end

    it "converts a simple string to a hash" do
      expect(described_class.hasherize_include_option("foo")).to eq("foo" => {})
    end

    it "converts a dotted string to a nested hash" do
      expect(described_class.hasherize_include_option("foo.bar")).to eq("foo" => {"bar" => {}})
    end

    it "converts a symbol to a hash" do
      expect(described_class.hasherize_include_option(:foo)).to eq("foo" => {})
    end

    it "merges multiple dotted strings from a comma-separated string" do
      expect(described_class.hasherize_include_option("foo.bar,foo.baz")).to eq(
        "foo" => {"bar" => {}, "baz" => {}}
      )
    end

    it "converts an array of strings to a merged hash" do
      expect(described_class.hasherize_include_option(["foo", "bar"])).to eq(
        "foo" => {}, "bar" => {}
      )
    end

    it "returns the object unchanged for unrecognized types" do
      expect(described_class.hasherize_include_option(42)).to eq(42)
    end
  end

  describe ".deep_merge" do
    it "merges two hashes recursively" do
      result = described_class.deep_merge({a: {b: 1}}, {a: {c: 2}})

      expect(result).to eq(a: {b: 1, c: 2})
    end

    it "uses the other value when both values are not hashes" do
      result = described_class.deep_merge({a: 1}, {a: 2})

      expect(result).to eq(a: 2)
    end
  end

  describe ".symbolize_hash" do
    it "symbolizes string keys" do
      expect(described_class.symbolize_hash("foo" => "bar")).to eq(foo: "bar")
    end

    it "symbolizes keys recursively" do
      expect(described_class.symbolize_hash("foo" => {"bar" => "baz"})).to eq(foo: {bar: "baz"})
    end

    it "returns non-hash values unchanged" do
      expect(described_class.symbolize_hash("foo")).to eq("foo")
    end
  end
end
