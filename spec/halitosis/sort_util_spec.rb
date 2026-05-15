# frozen_string_literal: true

RSpec.describe Halitosis::SortUtil do
  describe ".parse_sort_param" do
    context "with nil" do
      it "returns an empty array" do
        expect(described_class.parse_sort_param(nil)).to eq([])
      end
    end

    context "with an empty string" do
      it "returns an empty array" do
        expect(described_class.parse_sort_param("")).to eq([])
      end
    end

    context "with a whitespace-only string" do
      it "returns an empty array" do
        expect(described_class.parse_sort_param("   ")).to eq([])
      end
    end

    context "with an empty array" do
      it "returns an empty array" do
        expect(described_class.parse_sort_param([])).to eq([])
      end
    end

    context "with an unsupported type" do
      it "returns an empty array for an integer" do
        expect(described_class.parse_sort_param(42)).to eq([])
      end

      it "returns an empty array for a hash" do
        expect(described_class.parse_sort_param({name: :asc})).to eq([])
      end

      it "returns an empty array for true" do
        expect(described_class.parse_sort_param(true)).to eq([])
      end
    end

    context "with a single ascending field" do
      it "returns the field name with ascending true" do
        expect(described_class.parse_sort_param("name")).to eq([["name", true]])
      end
    end

    context "with a single descending field" do
      it "returns the field name with ascending false" do
        expect(described_class.parse_sort_param("-name")).to eq([["name", false]])
      end
    end

    context "with a symbol" do
      it "treats it as a string" do
        expect(described_class.parse_sort_param(:name)).to eq([["name", true]])
      end

      it "treats a symbol with leading dash as descending" do
        expect(described_class.parse_sort_param(:"-name")).to eq([["name", false]])
      end
    end

    context "with a comma-separated string" do
      it "parses multiple fields" do
        expect(described_class.parse_sort_param("name,-age")).to eq([
          ["name", true],
          ["age", false]
        ])
      end

      it "preserves field order" do
        expect(described_class.parse_sort_param("z,-a,m")).to eq([
          ["z", true],
          ["a", false],
          ["m", true]
        ])
      end

      it "strips surrounding whitespace from each token" do
        expect(described_class.parse_sort_param(" name , -age ")).to eq([
          ["name", true],
          ["age", false]
        ])
      end

      it "skips blank entries" do
        expect(described_class.parse_sort_param("name,,age")).to eq([
          ["name", true],
          ["age", true]
        ])
      end

      it "skips whitespace-only entries" do
        expect(described_class.parse_sort_param("name,  ,age")).to eq([
          ["name", true],
          ["age", true]
        ])
      end
    end

    context "with an array of strings" do
      it "parses each element" do
        expect(described_class.parse_sort_param(["name", "-age"])).to eq([
          ["name", true],
          ["age", false]
        ])
      end

      it "handles elements that are themselves comma-separated" do
        expect(described_class.parse_sort_param(["name,-age", "score"])).to eq([
          ["name", true],
          ["age", false],
          ["score", true]
        ])
      end

      it "handles an array containing an empty string" do
        expect(described_class.parse_sort_param(["name", ""])).to eq([["name", true]])
      end

      it "handles nested arrays recursively" do
        expect(described_class.parse_sort_param(["name", ["-age", "score"]])).to eq([
          ["name", true],
          ["age", false],
          ["score", true]
        ])
      end
    end
  end

  describe ".parse_sort_token" do
    it "returns the field name and ascending true for a plain token" do
      expect(described_class.parse_sort_token("name")).to eq(["name", true])
    end

    it "returns the field name and ascending false for a dashed token" do
      expect(described_class.parse_sort_token("-name")).to eq(["name", false])
    end

    it "strips only the leading dash, leaving the rest of the name intact" do
      expect(described_class.parse_sort_token("-created_at")).to eq(["created_at", false])
    end
  end
end
