# frozen_string_literal: true

RSpec.describe Halitosis::FilterUtil do
  describe ".parse_filter_param" do
    context "with a plain Hash" do
      it "returns an array of [key_string, value] pairs" do
        result = described_class.parse_filter_param({"name" => "Alice", "score" => "5"})

        expect(result).to eq([["name", "Alice"], ["score", "5"]])
      end

      it "converts symbol keys to strings" do
        result = described_class.parse_filter_param({name: "Alice"})

        expect(result).to eq([["name", "Alice"]])
      end

      it "returns an empty array for an empty hash" do
        expect(described_class.parse_filter_param({})).to eq([])
      end
    end

    context "with an ActionController::Parameters-like object" do
      it "accepts any object responding to each_pair" do
        params = {"name" => "Alice", "score" => "5"}.tap do |h|
          def h.each_pair = super
        end

        result = described_class.parse_filter_param(params)

        expect(result).to eq([["name", "Alice"], ["score", "5"]])
      end
    end

    context "with nested hashes" do
      it "flattens one level of nesting into dot-notation keys" do
        result = described_class.parse_filter_param({"user" => {"name" => "Alice"}})

        expect(result).to eq([["user.name", "Alice"]])
      end

      it "flattens multiple levels of nesting" do
        result = described_class.parse_filter_param({"a" => {"b" => {"c" => "deep"}}})

        expect(result).to eq([["a.b.c", "deep"]])
      end

      it "flattens mixed flat and nested keys" do
        result = described_class.parse_filter_param({"name" => "Bob", "user" => {"age" => "30"}})

        expect(result).to eq([["name", "Bob"], ["user.age", "30"]])
      end

      it "treats filter[user.name]=Alice identically to filter[user][name]=Alice" do
        dot_literal = described_class.parse_filter_param({"user.name" => "Alice"})
        nested = described_class.parse_filter_param({"user" => {"name" => "Alice"}})

        expect(dot_literal).to eq(nested)
      end
    end

    context "with non-hash input" do
      it "returns [] for nil" do
        expect(described_class.parse_filter_param(nil)).to eq([])
      end

      it "returns [] for a String" do
        expect(described_class.parse_filter_param("name=Alice")).to eq([])
      end

      it "returns [] for an Array" do
        expect(described_class.parse_filter_param(["name", "Alice"])).to eq([])
      end

      it "returns [] for an Integer" do
        expect(described_class.parse_filter_param(42)).to eq([])
      end
    end

    context "with compound_names:" do
      it "stops flattening when a key matches a compound name" do
        result = described_class.parse_filter_param(
          {"start_date" => {"from" => "2024-01-01", "to" => "2024-12-31"}},
          compound_names: ["start_date"]
        )

        expect(result).to eq([["start_date", {"from" => "2024-01-01", "to" => "2024-12-31"}]])
      end

      it "still flattens keys not in compound_names" do
        result = described_class.parse_filter_param(
          {"user" => {"name" => "Alice"}, "start_date" => {"from" => "2024-01-01"}},
          compound_names: ["start_date"]
        )

        expect(result).to contain_exactly(
          ["user.name", "Alice"],
          ["start_date", {"from" => "2024-01-01"}]
        )
      end

      it "stops at the compound name when nested inside a namespace" do
        result = described_class.parse_filter_param(
          {"item" => {"start_date" => {"from" => "2024-01-01", "to" => "2024-12-31"}}},
          compound_names: ["item.start_date"]
        )

        expect(result).to eq([["item.start_date", {"from" => "2024-01-01", "to" => "2024-12-31"}]])
      end

      it "passes a scalar value through unchanged for a compound name" do
        result = described_class.parse_filter_param(
          {"start_date" => "2024-01-01"},
          compound_names: ["start_date"]
        )

        expect(result).to eq([["start_date", "2024-01-01"]])
      end

      it "returns normal flat pairs when compound_names is empty" do
        result = described_class.parse_filter_param(
          {"start_date" => {"from" => "2024-01-01"}},
          compound_names: []
        )

        expect(result).to eq([["start_date.from", "2024-01-01"]])
      end
    end
  end
end
