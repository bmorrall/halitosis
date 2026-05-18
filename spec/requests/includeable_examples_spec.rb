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
  end
end
