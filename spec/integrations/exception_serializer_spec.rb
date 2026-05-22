# frozen_string_literal: true

return unless defined?(Rails)

RSpec.describe "ExceptionSerializer", :rails do
  let(:exception) { StandardError.new("You are not authorized") }

  context "when subclassing ErrorEntry" do
    subject(:result) do
      Halitosis::ExceptionSerializer.new(exception, error_serializer_class: entry_class).as_json
    end

    let(:entry_class) do
      Class.new(Halitosis::ErrorEntry) do
        code { "unauthorized" }
        title { "Unauthorized" }
        detail { error.message }
        source_header { "Authorization" }
        link(:about) { "https://docs.example.com/errors/unauthorized" }
        meta(:timestamp) { "2024-01-01T00:00:00Z" }
      end
    end

    it "renders one entry in the errors array", :aggregate_failures do
      expect(result["errors"]).to be_an(Array).and have_attributes(size: 1)

      entry = result["errors"].first
      expect(entry["code"]).to eq("unauthorized")
      expect(entry["title"]).to eq("Unauthorized")
      expect(entry["detail"]).to eq("You are not authorized")
      expect(entry["source"]).to eq("header" => "Authorization")
      expect(entry["_links"]).to eq("about" => {"href" => "https://docs.example.com/errors/unauthorized"})
      expect(entry["_meta"]).to eq("timestamp" => "2024-01-01T00:00:00Z")
    end
  end

  context "when using .build" do
    it "makes the exception accessible as `error` in attribute blocks" do
      result = Halitosis::ExceptionSerializer.build(exception) {
        detail { error.message }
      }.as_json

      expect(result["errors"].first["detail"]).to eq("You are not authorized")
    end

    it "renders source_pointer correctly" do
      result = Halitosis::ExceptionSerializer.build(exception) {
        source_pointer { "/data/attributes/email" }
      }.as_json

      expect(result["errors"].first["source"]).to eq("pointer" => "/data/attributes/email")
    end

    it "renders source_parameter correctly" do
      result = Halitosis::ExceptionSerializer.build(exception) {
        source_parameter { "sort" }
      }.as_json

      expect(result["errors"].first["source"]).to eq("parameter" => "sort")
    end

    it "renders source_header correctly" do
      result = Halitosis::ExceptionSerializer.build(exception) {
        source_header { "X-Api-Key" }
      }.as_json

      expect(result["errors"].first["source"]).to eq("header" => "X-Api-Key")
    end
  end
end
