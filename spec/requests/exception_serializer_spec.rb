require "spec_helper"

RSpec.describe "ExceptionError", :rails, type: :request do
  let(:expected_errors) do
    [
      {
        "code" => "unauthorized",
        "title" => "Unauthorized",
        "detail" => "Token is missing or invalid",
        "source" => {"header" => "Authorization"}
      }
    ]
  end

  describe "GET /exception_error" do
    it "returns 401 with a JSON:API errors array" do
      get exception_error_path

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["errors"]).to match(expected_errors)
    end
  end

  describe "GET /exception_error/json" do
    it "returns 401 with a JSON:API errors array" do
      get json_exception_error_path

      expect(response).to have_http_status(:unauthorized)
      expect(response.content_type).to include("application/json")
      expect(response.parsed_body["errors"]).to match(expected_errors)
    end
  end
end
