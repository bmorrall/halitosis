require "spec_helper"

RSpec.describe "ComplexRenderables", :rails, type: :request do
  describe "GET /complex_renerables/1" do
    it "renders the example as json", :aggregate_failures do
      get complex_renderable_path(1)

      expect(response).to have_http_status(:ok)

      expect(response.media_type).to eq Mime[:json]

      expect(response.parsed_body).to match(
        "complex" => {
          "id" => 1,
          "name" => "Complex 1"
        }
      )
    end

    it "allows for single relationships to be included", :aggregate_failures do
      get complex_renderable_path(1), params: {include: "single"}

      expect(response).to have_http_status(:ok)

      expect(response.media_type).to eq Mime[:json]

      expect(response.parsed_body).to match(
        "complex" => {
          "id" => 1,
          "name" => "Complex 1",
          "_relationships" => {
            "single" => {
              "id" => 11,
              "name" => "Complex 1-1"
            }
          }
        }
      )
    end

    it "allows for multiple relationships to be included", :aggregate_failures do
      get complex_renderable_path(1), params: {include: "multiple"}

      expect(response).to have_http_status(:ok)

      expect(response.media_type).to eq Mime[:json]

      expect(response.parsed_body).to match(
        "complex" => {
          "id" => 1,
          "name" => "Complex 1",
          "_relationships" => {
            "multiple" => [
              {
                "id" => 11,
                "name" => "Complex 1-1"
              },
              {
                "id" => 12,
                "name" => "Complex 1-2"
              }
            ]
          }
        }
      )
    end
  end
end
