require "spec_helper"

RSpec.describe "ExceptionError", :rails, type: :request do
  describe "GET /exception_error" do
    it "returns 401 with a JSON:API errors array" do
      get exception_error_path

      expect(response).to have_http_status(:unauthorized)

      expect(response.parsed_body["errors"]).to match([
        {
          "code" => "unauthorized",
          "title" => "Unauthorized",
          "detail" => "Token is missing or invalid",
          "source" => {"header" => "Authorization"}
        }
      ])
    end
  end
end
