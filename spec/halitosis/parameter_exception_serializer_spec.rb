# frozen_string_literal: true

return unless defined?(Rails)

RSpec.describe Halitosis::ParameterExceptionSerializer, :rails do
  subject(:serializer) { described_class.new(error) }

  describe "#as_json" do
    context "with an InvalidSortParameter" do
      let(:error) { Halitosis::InvalidSortParameter.new("Cannot sort by '-name'") }

      it "returns an errors array with I18n id and title", :aggregate_failures do
        result = serializer.as_json

        expect(result["errors"]).to be_an(Array).and have_attributes(size: 1)

        error_object = result["errors"].first
        expect(error_object["id"]).to eq("invalid_sort_parameter")
        expect(error_object["title"]).to eq("Invalid Sort Parameter")
        expect(error_object["detail"]).to eq("Cannot sort by '-name'")
        expect(error_object["source"]).to eq("parameter" => "sort")
      end
    end

    context "with an InvalidIncludeParameter" do
      let(:error) { Halitosis::InvalidIncludeParameter.new("Cannot include 'unknown'") }

      it "sets source parameter to 'include'" do
        result = serializer.as_json

        expect(result["errors"].first["source"]).to eq("parameter" => "include")
      end
    end

    context "with an InvalidQueryParameter with a custom parameter" do
      let(:error) { Halitosis::InvalidQueryParameter.new("Bad param", "filter") }

      it "uses the custom parameter name in source" do
        result = serializer.as_json

        expect(result["errors"].first["source"]).to eq("parameter" => "filter")
      end

      it "falls back to class-based I18n for id and title" do
        result = serializer.as_json

        expect(result["errors"].first["id"]).to eq("invalid_query_parameter")
        expect(result["errors"].first["title"]).to eq("Invalid Query Parameter")
      end
    end

    context "with a plain Halitosis::Error (no parameter)" do
      let(:error) { Halitosis::Error.new("Something went wrong") }

      it "omits the source key" do
        result = serializer.as_json

        expect(result["errors"].first).not_to have_key("source")
      end

      it "falls back to a titleized class name for title when no I18n entry exists" do
        result = serializer.as_json

        expect(result["errors"].first["title"]).to eq("Error")
      end

      it "omits id when no I18n entry exists" do
        result = serializer.as_json

        expect(result["errors"].first).not_to have_key("id")
      end
    end
  end
end
