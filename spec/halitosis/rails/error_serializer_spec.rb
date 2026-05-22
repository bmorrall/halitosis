# frozen_string_literal: true

return unless defined?(Rails)

RSpec.describe Halitosis::ErrorSerializer, :rails do
  subject(:serializer) { described_class.new(error: error, param: "article") }

  let(:error_class) { Struct.new(:type, :full_message, :attribute, keyword_init: true) }

  describe "#as_json" do
    context "with a field error" do
      let(:error) { error_class.new(type: :blank, full_message: "Title can't be blank", attribute: :title) }

      it "includes code, detail, and source pointer" do
        result = serializer.as_json

        expect(result["code"]).to eq("title_blank")
        expect(result["detail"]).to eq("Title can't be blank")
        expect(result["source"]).to eq("pointer" => "/article/title")
      end
    end

    context "with a base error" do
      let(:error) { error_class.new(type: :forbidden, full_message: "You are not allowed to do this", attribute: :base) }

      it "uses type as code and omits source" do
        result = serializer.as_json

        expect(result["code"]).to eq("forbidden")
        expect(result["detail"]).to eq("You are not allowed to do this")
        expect(result).not_to have_key("source")
      end
    end

    context "with a non-symbol error type" do
      let(:error) { error_class.new(type: "custom string type", full_message: "Something went wrong", attribute: :title) }

      it "omits code" do
        result = serializer.as_json

        expect(result).not_to have_key("code")
      end
    end

    context "with a nil attribute error" do
      let(:error) { error_class.new(type: :invalid, full_message: "is invalid", attribute: nil) }

      it "omits source" do
        result = serializer.as_json

        expect(result).not_to have_key("source")
      end
    end
  end

  describe "subclassing" do
    subject(:serializer) { custom_class.new(error: error, param: "article") }

    let(:custom_class) do
      Class.new(described_class) do
        attribute(:title) { "#{error.attribute}_error".humanize }
      end
    end

    let(:error) { error_class.new(type: :blank, full_message: "Title can't be blank", attribute: :title) }

    it "includes the extra attribute alongside the base fields" do
      result = serializer.as_json

      expect(result["code"]).to eq("title_blank")
      expect(result["title"]).to eq("Title error")
      expect(result["detail"]).to eq("Title can't be blank")
    end
  end

  describe "missing required options" do
    let(:error) { error_class.new(type: :blank, full_message: "can't be blank", attribute: :title) }

    it "raises MissingOption when error is absent" do
      expect { described_class.new(param: "article") }.to raise_error(Halitosis::MissingOption)
    end

    it "raises MissingOption when param is absent" do
      expect { described_class.new(error: error) }.to raise_error(Halitosis::MissingOption)
    end
  end

  describe "field restrictions" do
    it "does not support identifier" do
      expect { described_class.identifier(:id) }.to raise_error(NoMethodError)
    end

    it "does not support permission" do
      expect { described_class.permission(:read) { true } }.to raise_error(NoMethodError)
    end

    it "does not support relationship" do
      expect { described_class.relationship(:author) { nil } }.to raise_error(NoMethodError)
    end
  end
end
