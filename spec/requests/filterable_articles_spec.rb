require "spec_helper"

RSpec.describe "FilterableArticles", :rails, type: :request do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Schema.define do
      create_table :articles, force: true do |t|
        t.string :name
        t.integer :score
        t.date :published_on
      end
    end
  end

  before do
    Article.create!(name: "Alpha", score: 1)
    Article.create!(name: "Bravo", score: 2)
    Article.create!(name: "Charlie", score: 2)
  end

  after do
    Article.delete_all
  end

  describe "GET /filterable_articles" do
    context "when no filter param is provided" do
      it "returns HTTP 200 and all articles" do
        get filterable_articles_path

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["articles"].size).to eq(3)
        expect(response.parsed_body.dig("_links", "self", "href")).to eq(filterable_articles_path)
      end
    end

    context "when filtering by name" do
      it "returns only articles with the matching name" do
        get filterable_articles_path, params: {filter: {name: "Alpha"}}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        expect(names).to eq(["Alpha"])
        expect(response.parsed_body.dig("_links", "self", "href")).to eq(filterable_articles_path(filter: {name: "Alpha"}))
      end

      it "returns an empty list when no articles match" do
        get filterable_articles_path, params: {filter: {name: "Zulu"}}

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["articles"]).to eq([])
      end
    end

    context "when filtering by score" do
      it "returns only articles with the matching score" do
        get filterable_articles_path, params: {filter: {score: "2"}}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        expect(names).to contain_exactly("Bravo", "Charlie")
      end
    end

    context "when filtering by multiple fields (AND logic)" do
      it "applies both filters and returns the intersection" do
        get filterable_articles_path, params: {filter: {name: "Bravo", score: "2"}}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        expect(names).to eq(["Bravo"])
        expect(response.parsed_body.dig("_links", "self", "href")).to eq(filterable_articles_path(filter: {name: "Bravo", score: "2"}))
      end
    end

    context "with an invalid score value" do
      it "returns 400 Bad Request" do
        get filterable_articles_path, params: {filter: {score: "not_a_number"}}

        expect(response).to have_http_status(:bad_request)

        expect(response.parsed_body["errors"].first).to match(
          "code" => "invalid_filter_parameter",
          "title" => "Invalid Filter Parameter",
          "detail" => "The articles collection can not be filtered by 'score': The provided value is invalid.",
          "source" => {"parameter" => "filter[score]"}
        )
      end

      it "does not reflect the bad value in the response" do
        get filterable_articles_path, params: {filter: {score: "sensitive_payload"}}

        expect(response.body).not_to include("sensitive_payload")
      end
    end

    context "with an unknown filter key" do
      it "returns 400 Bad Request" do
        get filterable_articles_path, params: {filter: {unknown: "x"}}

        expect(response).to have_http_status(:bad_request)

        expect(response.parsed_body["errors"].first).to match(
          "code" => "invalid_filter_parameter",
          "title" => "Invalid Filter Parameter",
          "detail" => "The articles collection can not be filtered by 'unknown'",
          "source" => {"parameter" => "filter[unknown]"}
        )
      end
    end
  end
end
