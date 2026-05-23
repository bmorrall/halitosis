require "spec_helper"

RSpec.describe "ValidationErrors", :rails, type: :request do
  let(:expected_errors) do
    [
      {
        "code" => "name_blank",
        "detail" => "Name can't be blank",
        "source" => {"pointer" => "/example/name"}
      },
      {
        "detail" => "You are not permitted to perform this action"
      }
    ]
  end

  describe "POST /validation_errors" do
    it "returns 422 with a JSON:API errors array" do
      post validation_errors_path

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to match(expected_errors)
    end
  end

  describe "POST /validation_errors/json" do
    it "returns 422 with a JSON:API errors array" do
      post json_validation_errors_path

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.content_type).to include("application/json")
      expect(response.parsed_body["errors"]).to match(expected_errors)
    end
  end

  describe "POST /validation_errors/inferred" do
    it "infers the param from the model class and returns correct source pointers" do
      post inferred_validation_errors_path

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to match(expected_errors)
    end
  end
end
