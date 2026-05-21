require "spec_helper"

RSpec.describe "ValidationErrors", :rails, type: :request do
  describe "POST /validation_errors" do
    it "returns 422 with a JSON:API errors array" do
      post validation_errors_path

      expect(response).to have_http_status(:unprocessable_entity)

      expect(response.parsed_body["errors"]).to match([
        {
          "code" => "name_blank",
          "detail" => "Name can't be blank",
          "source" => {"pointer" => "/example/name"}
        },
        {
          "detail" => "You are not permitted to perform this action"
        }
      ])
    end
  end
end
