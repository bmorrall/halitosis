require "spec_helper"

RSpec.describe "TypedArticles", :rails, type: :request do
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
    Article.create!(name: "Alpha", score: 1, published_on: "2024-01-15")
    Article.create!(name: "Bravo", score: 2, published_on: "2024-06-01")
    Article.create!(name: "Charlie", score: 2, published_on: "2024-11-20")
  end

  after do
    Article.delete_all
  end

  describe "GET /typed_articles" do
    context "when filtering by score with a valid integer string" do
      it "casts the value and returns matching articles" do
        get typed_articles_path, params: {filter: {score: "2"}}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        expect(names).to contain_exactly("Bravo", "Charlie")
      end
    end

    context "when filtering by published_on with a valid date string" do
      it "casts the value and returns the matching article" do
        get typed_articles_path, params: {filter: {published_on: "2024-06-01"}}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        expect(names).to eq(["Bravo"])
      end
    end

    context "when filtering by published_on with an invalid date string" do
      it "returns 400 Bad Request" do
        get typed_articles_path, params: {filter: {published_on: "not-a-date"}}

        expect(response).to have_http_status(:bad_request)

        expect(response.parsed_body["errors"].first).to match(
          "code" => "invalid_filter_parameter",
          "title" => "Invalid Filter Parameter",
          "detail" => "The articles collection can not be filtered by 'published_on'",
          "source" => {"parameter" => "filter[published_on]"}
        )
      end

      it "does not reflect the bad value in the response" do
        get typed_articles_path, params: {filter: {published_on: "sensitive_payload"}}

        expect(response.body).not_to include("sensitive_payload")
      end
    end
  end
end
