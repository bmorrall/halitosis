# frozen_string_literal: true

return unless defined?(Rails)

RSpec.describe Halitosis::ExceptionSerializer, :rails do
  let(:exception) { StandardError.new("Something went wrong") }

  describe "::ErrorEntry" do
    it "raises MissingOption when error is not provided" do
      expect { described_class::ErrorEntry.new }.to raise_error(Halitosis::MissingOption)
    end

    it "renders an empty hash when no fields are defined" do
      result = described_class::ErrorEntry.new(error: exception).as_json

      expect(result).to eq({})
    end
  end

  describe "::ClassMethods" do
    subject(:entry_class) { Class.new(described_class::ErrorEntry) }

    %i[id code title status detail].each do |field|
      describe "##{field}" do
        it "defines a #{field} attribute" do
          entry_class.public_send(field) { field.to_s.upcase }

          result = entry_class.new(error: exception).as_json

          expect(result[field.to_s]).to eq(field.to_s.upcase)
        end
      end
    end

    describe "#source_pointer" do
      it "renders source with pointer key" do
        entry_class.source_pointer { "/data/attributes/title" }

        result = entry_class.new(error: exception).as_json

        expect(result["source"]).to eq("pointer" => "/data/attributes/title")
      end
    end

    describe "#source_parameter" do
      it "renders source with parameter key" do
        entry_class.source_parameter { "sort" }

        result = entry_class.new(error: exception).as_json

        expect(result["source"]).to eq("parameter" => "sort")
      end
    end

    describe "#source_header" do
      it "renders source with header key" do
        entry_class.source_header { "Authorization" }

        result = entry_class.new(error: exception).as_json

        expect(result["source"]).to eq("header" => "Authorization")
      end
    end

    it "exposes the exception as `error` in attribute blocks" do
      entry_class.detail { error.message }

      result = entry_class.new(error: exception).as_json

      expect(result["detail"]).to eq("Something went wrong")
    end
  end

  describe ".build" do
    it "returns an ExceptionSerializer instance" do
      result = described_class.build(exception)

      expect(result).to be_a(described_class)
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

    it "renders an empty error entry when no fields are defined" do
      result = described_class.build(exception).as_json

      expect(result["errors"]).to eq([{}])
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
      custom_class = Class.new(described_class::ErrorEntry) do
        code { "custom" }
      end

      result = described_class.new(exception, error_serializer_class: custom_class).as_json

      expect(result["errors"].first["code"]).to eq("custom")
    end
  end
end
