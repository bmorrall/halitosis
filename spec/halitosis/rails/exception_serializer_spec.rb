# frozen_string_literal: true

return unless defined?(Rails)

RSpec.describe Halitosis::ExceptionSerializer, :rails do
  let(:exception) { StandardError.new("Something went wrong") }

  describe ".build" do
    it "returns an ExceptionSerializer instance" do
      result = described_class.build(exception) { code { "error" } }

      expect(result).to be_a(described_class)
    end

    it "raises ArgumentError when called without a block" do
      expect { described_class.build(exception) }.to raise_error(ArgumentError, /requires a block/)
    end

    it "raises ArgumentError when the block defines no fields" do
      expect { described_class.build(exception) {} }.to raise_error(ArgumentError, /at least one attribute, link, or meta field/)
    end

    it "wraps the exception in a single-element errors array" do
      result = described_class.build(exception) { code { "error" } }.as_json

      expect(result["errors"]).to be_an(Array).and have_attributes(size: 1)
    end

    it "renders fields defined in the DSL block" do
      result = described_class.build(exception) {
        code { "unauthorized" }
        detail { error.message }
      }.as_json

      error_object = result["errors"].first
      expect(error_object["code"]).to eq("unauthorized")
      expect(error_object["detail"]).to eq("Something went wrong")
    end

    context "with source shortcuts" do
      it "renders source_pointer" do
        result = described_class.build(exception) {
          source_pointer { "/data/attributes/email" }
        }.as_json

        expect(result["errors"].first["source"]).to eq("pointer" => "/data/attributes/email")
      end

      it "renders source_parameter" do
        result = described_class.build(exception) {
          source_parameter { "sort" }
        }.as_json

        expect(result["errors"].first["source"]).to eq("parameter" => "sort")
      end

      it "renders source_header" do
        result = described_class.build(exception) {
          source_header { "Authorization" }
        }.as_json

        expect(result["errors"].first["source"]).to eq("header" => "Authorization")
      end
    end
  end

  describe "#initialize" do
    it "wraps the exception in an errors array" do
      result = described_class.new(exception).as_json

      expect(result["errors"]).to eq([{}])
    end

    it "accepts a custom error_serializer_class" do
      custom_class = Class.new(Halitosis::ErrorEntry) do
        code { "custom" }
      end

      result = described_class.new(exception, error_serializer_class: custom_class).as_json

      expect(result["errors"].first["code"]).to eq("custom")
    end
  end
end
