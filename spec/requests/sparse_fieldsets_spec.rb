require "spec_helper"

RSpec.describe "Sparse fieldsets via request params", :rails, type: :request do
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
    Article.create!(name: "Beta", score: 2)
  end

  after { Article.delete_all }

  # ArticleSerializer has resource_type "article" (set by `resource :article`)
  # and defines attributes :name and :score.
  #
  describe "GET /sortable_articles with fields param" do
    it "returns all attributes when no fields param is given" do
      get sortable_articles_path

      expect(response).to have_http_status(:ok)

      articles = response.parsed_body["articles"]
      expect(articles.first).to include("name", "score")
    end

    it "returns only requested fields for the matching resource type" do
      get sortable_articles_path, params: {fields: {article: "name"}}

      expect(response).to have_http_status(:ok)

      articles = response.parsed_body["articles"]
      expect(articles.first).to include("name" => "Alpha")
      expect(articles.first).not_to have_key("score")
    end

    it "returns all fields when fields targets a different resource type" do
      get sortable_articles_path, params: {fields: {people: "name"}}

      expect(response).to have_http_status(:ok)

      articles = response.parsed_body["articles"]
      expect(articles.first).to include("name", "score")
    end

    it "records the fields param in query_params returned in the self link" do
      get sortable_articles_path, params: {fields: {article: "name"}}

      expect(response).to have_http_status(:ok)

      self_href = response.parsed_body.dig("_links", "self", "href")
      expect(self_href).to eq(sortable_articles_path(fields: {article: "name"}))
    end
  end
end
