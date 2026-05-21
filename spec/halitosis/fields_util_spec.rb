# frozen_string_literal: true

RSpec.describe Halitosis::FieldsUtil do
  describe ".parse_field_names" do
    it "returns an empty Set for nil" do
      expect(described_class.parse_field_names(nil)).to eq(Set[])
    end

    it "returns an empty Set for an empty string" do
      expect(described_class.parse_field_names("")).to eq(Set[])
    end

    it "returns an empty Set for a whitespace-only string" do
      expect(described_class.parse_field_names("   ")).to eq(Set[])
    end

    it "returns an empty Set for an empty array" do
      expect(described_class.parse_field_names([])).to eq(Set[])
    end

    it "returns nil for an unsupported type" do
      expect(described_class.parse_field_names(42)).to be_nil
    end

    it "parses a single field name string" do
      expect(described_class.parse_field_names("title")).to eq(Set["title"])
    end

    it "parses a symbol" do
      expect(described_class.parse_field_names(:title)).to eq(Set["title"])
    end

    it "parses a comma-separated string into a Set" do
      expect(described_class.parse_field_names("title,body")).to eq(Set["title", "body"])
    end

    it "strips whitespace around field names" do
      expect(described_class.parse_field_names(" title , body ")).to eq(Set["title", "body"])
    end

    it "parses an array of strings" do
      expect(described_class.parse_field_names(["title", "body"])).to eq(Set["title", "body"])
    end

    it "parses an array of symbols" do
      expect(described_class.parse_field_names([:title, :body])).to eq(Set["title", "body"])
    end

    it "parses an array containing comma-separated strings" do
      expect(described_class.parse_field_names(["title,body", "author"])).to eq(Set["title", "body", "author"])
    end
  end

  describe ".build_registry" do
    it "returns nil for nil" do
      expect(described_class.build_registry(nil)).to be_nil
    end

    it "returns nil for a non-hash" do
      expect(described_class.build_registry("title")).to be_nil
    end

    it "returns nil when all entries are unsupported types" do
      expect(described_class.build_registry({articles: 42})).to be_nil
    end

    it "includes an empty Set entry when the field list is blank" do
      result = described_class.build_registry({articles: ""})

      expect(result).to eq("articles" => Set[])
    end

    it "includes an empty Set entry when the field value is nil" do
      result = described_class.build_registry({articles: nil})

      expect(result).to eq("articles" => Set[])
    end

    it "builds a registry hash from a string-keyed hash" do
      result = described_class.build_registry("articles" => "title,body")

      expect(result).to eq("articles" => Set["title", "body"])
    end

    it "builds a registry hash from a symbol-keyed hash" do
      result = described_class.build_registry(articles: "title,body")

      expect(result).to eq("articles" => Set["title", "body"])
    end

    it "handles multiple resource types" do
      result = described_class.build_registry(
        articles: "title,body",
        people: "name"
      )

      expect(result).to eq(
        "articles" => Set["title", "body"],
        "people" => Set["name"]
      )
    end

    it "includes a blank entry as an empty Set rather than omitting it" do
      result = described_class.build_registry(articles: "title", people: "")

      expect(result).to eq("articles" => Set["title"], "people" => Set[])
    end
  end
end
