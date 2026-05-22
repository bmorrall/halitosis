# frozen_string_literal: true

return unless defined?(Rails)

RSpec.describe Halitosis::ErrorsSerializer, :rails do
  subject(:serializer) { described_class.new(errors, param: "article") }

  let(:error_class) { Struct.new(:type, :full_message, :attribute, keyword_init: true) }

  describe ".build" do
    let(:errors) { [error_class.new(type: :blank, full_message: "Title can't be blank", attribute: :title)] }

    it "returns an ErrorsSerializer instance" do
      result = described_class.build(errors, param: "article") { title { "Validation Error" } }

      expect(result).to be_a(described_class)
    end

    it "raises ArgumentError when called without a block" do
      expect { described_class.build(errors, param: "article") }.to raise_error(ArgumentError, /requires a block/)
    end

    it "accepts an empty block and falls back to ErrorSerializer defaults" do
      result = described_class.build(errors, param: "article") {}.as_json

      error_object = result["errors"].first
      expect(error_object["code"]).to eq("title_blank")
      expect(error_object["detail"]).to eq("Title can't be blank")
    end

    it "inherits code and detail from ErrorSerializer" do
      result = described_class.build(errors, param: "article") {
        title { "Validation Error" }
      }.as_json

      error_object = result["errors"].first
      expect(error_object["code"]).to eq("title_blank")
      expect(error_object["detail"]).to eq("Title can't be blank")
    end

    it "renders one entry per error" do
      two_errors = [
        error_class.new(type: :blank, full_message: "Title can't be blank", attribute: :title),
        error_class.new(type: :too_short, full_message: "Body is too short", attribute: :body)
      ]

      result = described_class.build(two_errors, param: "article") { title { "Error" } }.as_json

      expect(result["errors"]).to have_attributes(size: 2)
    end

    it "overrides the default source pointer with source_parameter" do
      result = described_class.build(errors, param: "article") {
        source_parameter { "filter[status]" }
      }.as_json

      expect(result["errors"].first["source"]).to eq("parameter" => "filter[status]")
    end

    it "overrides the default source pointer with a custom source_pointer" do
      result = described_class.build(errors, param: "article") {
        source_pointer { "/data/relationships/tags" }
      }.as_json

      expect(result["errors"].first["source"]).to eq("pointer" => "/data/relationships/tags")
    end
  end

  describe "#as_json" do
    context "with a field error" do
      let(:errors) { [error_class.new(type: :blank, full_message: "Title can't be blank", attribute: :title)] }

      it "returns an errors array with code, detail, and source pointer" do
        result = serializer.as_json

        expect(result["errors"]).to be_an(Array).and have_attributes(size: 1)

        error_object = result["errors"].first
        expect(error_object["code"]).to eq("title_blank")
        expect(error_object["detail"]).to eq("Title can't be blank")
        expect(error_object["source"]).to eq("pointer" => "/article/title")
      end
    end

    context "with a base error" do
      let(:errors) { [error_class.new(type: :forbidden, full_message: "You are not allowed to do this", attribute: :base)] }

      it "uses the type as the code and omits source" do
        result = serializer.as_json

        error_object = result["errors"].first
        expect(error_object["code"]).to eq("forbidden")
        expect(error_object["detail"]).to eq("You are not allowed to do this")
        expect(error_object).not_to have_key("source")
      end
    end

    context "with a non-symbol error type" do
      let(:errors) { [error_class.new(type: "custom string type", full_message: "Something went wrong", attribute: :title)] }

      it "omits the code" do
        result = serializer.as_json

        error_object = result["errors"].first
        expect(error_object).not_to have_key("code")
      end
    end

    context "with multiple errors" do
      let(:errors) do
        [
          error_class.new(type: :blank, full_message: "Title can't be blank", attribute: :title),
          error_class.new(type: :too_short, full_message: "Body is too short", attribute: :body),
          error_class.new(type: :invalid, full_message: "Record is invalid", attribute: :base)
        ]
      end

      it "returns one entry per error" do
        result = serializer.as_json

        expect(result["errors"]).to have_attributes(size: 3)
      end

      it "sets the correct pointers for field errors" do
        result = serializer.as_json
        pointers = result["errors"].filter_map { |e| e.dig("source", "pointer") }

        expect(pointers).to eq(["/article/title", "/article/body"])
      end
    end

    context "with an empty errors collection" do
      let(:errors) { [] }

      it "returns an empty errors array" do
        result = serializer.as_json

        expect(result["errors"]).to eq([])
      end
    end
  end

  describe "missing required options" do
    it "raises ArgumentError when errors is absent" do
      expect { described_class.new(param: "article") }.to raise_error(ArgumentError)
    end

    it "raises MissingOption when param is absent" do
      expect { described_class.new([]) }.to raise_error(Halitosis::MissingOption)
    end
  end

  describe ":error_serializer_class option" do
    subject(:serializer) { described_class.new(errors, param: "article", error_serializer_class: custom_class) }

    let(:custom_class) do
      Class.new(Halitosis::ErrorSerializer) do
        attribute(:title) { "Custom title" }
      end
    end

    let(:errors) { [error_class.new(type: :blank, full_message: "Title can't be blank", attribute: :title)] }

    it "uses the provided class to render each error" do
      result = serializer.as_json

      expect(result["errors"].first["title"]).to eq("Custom title")
    end
  end
end
