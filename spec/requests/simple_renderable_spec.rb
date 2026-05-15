require "spec_helper"

RSpec.describe "SimpleRenderables", :rails, type: :request do
  describe "GET /simple_renerables" do
    it "renders the examples as json", :aggregate_failures do
      get simple_renderables_path

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

  describe "GET /simple_renerables/1" do
    it "renders the example as json", :aggregate_failures do
      get simple_renderable_path(1)

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
