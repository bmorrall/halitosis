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
  end
end
