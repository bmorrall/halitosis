require "spec_helper"

RSpec.describe "SimpleJsons", :rails, type: :request do
  describe "GET /simple_jsons" do
    it "renders the examples as json", :aggregate_failures do
      get simple_jsons_path

      expect(response).to have_http_status(:ok)

      expect(response.media_type).to eq Mime[:json]

      expect(response.parsed_body).to match(
        "simples" => [
          {
            "id" => 1,
            "name" => "Simple 1",
            "_type" => "simple"
          }
        ]
      )
    end
  end

  describe "GET /simple_jsons/1" do
    it "renders the example as json", :aggregate_failures do
      get simple_json_path(1)

      expect(response).to have_http_status(:ok)

      expect(response.media_type).to eq Mime[:json]

      expect(response.parsed_body).to match(
        "simple" => {
          "id" => 1,
          "name" => "Simple 1",
          "_type" => "simple"
        }
      )
    end
  end
end
