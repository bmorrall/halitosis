require "spec_helper"

RSpec.describe "IncludeableExamples", :rails, type: :request do
  describe "GET /includeable_examples/:id" do
    it "renders without relationships when no include param is given" do
      get includeable_example_path(1)

      expect(response).to have_http_status(:ok)

      expect(response.parsed_body).not_to have_key("_relationships")
    end

    it "renders parts without transformation when include=parts", :aggregate_failures do
      get includeable_example_path(1), params: {include: "parts"}

      expect(response).to have_http_status(:ok)

      parts = response.parsed_body.dig("example", "_relationships", "parts")

      expect(parts).to be_an(Array)
      expect(parts.map { |p| p["name"] }).to eq(["Part A", "Part B"])
    end

    it "applies the :detail procedure when include=parts.detail", :aggregate_failures do
      get includeable_example_path(1), params: {include: "parts.detail"}

      expect(response).to have_http_status(:ok)

      parts = response.parsed_body.dig("example", "_relationships", "parts")

      expect(parts).to be_an(Array)
      expect(parts.map { |p| p["name"] }).to eq(["Part A (detailed)", "Part B (detailed)"])
    end

    context "when allow_undeclared_includes is false" do
      around do |example|
        original = Halitosis.config.allow_undeclared_includes
        Halitosis.config.allow_undeclared_includes = false
        example.run
      ensure
        Halitosis.config.allow_undeclared_includes = original
      end

      it "returns 400 Bad Request for an undeclared include" do
        get includeable_example_path(1), params: {include: "unknown"}

        expect(response).to have_http_status(:bad_request)

        error = response.parsed_body["errors"].first
        expect(error["id"]).to eq("invalid_include_parameter")
        expect(error["title"]).to eq("Invalid Include Parameter")
        expect(error["detail"]).to match(/does not support the `unknown` include/)
        expect(error["source"]).to eq("parameter" => "include")
      end
    end
  end
end
