require "spec_helper"

RSpec.describe "Halitosis::ErrorHandling", :rails, type: :request do
  describe "invalid sort parameter" do
    it "returns 400 with a JSON errors array" do
      get sortable_articles_path, params: {sort: "nonexistent"}

      expect(response).to have_http_status(:bad_request)

      expect(response.parsed_body["errors"]).to match([
        {
          "code" => "invalid_sort_parameter",
          "title" => "Invalid Sort Parameter",
          "detail" => "The articles collection can not be sorted by 'nonexistent'",
          "source" => {"parameter" => "sort"}
        }
      ])
    end
  end

  describe "invalid include parameter" do
    it "returns 400 with a JSON errors array" do
      get simple_renderable_path(1), params: {include: "nonexistent"}

      expect(response).to have_http_status(:bad_request)

      expect(response.parsed_body["errors"]).to match([
        {
          "code" => "invalid_include_parameter",
          "title" => "Invalid Include Parameter",
          "detail" => "The simple resource does not have a `nonexistent` relationship path.",
          "source" => {"parameter" => "include"}
        }
      ])
    end
  end

  describe "invalid pagination parameter" do
    it "returns 400 with a JSON errors array" do
      get paginatable_articles_path, params: {page: {number: "not-a-number"}}

      expect(response).to have_http_status(:bad_request)

      expect(response.parsed_body["errors"]).to match([
        {
          "code" => "invalid_pagination_parameter",
          "title" => "Invalid Pagination Parameter",
          "detail" => "The articles collection can not be paginated with the provided 'page[number]' value",
          "source" => {"parameter" => "page"}
        }
      ])
    end
  end
end
