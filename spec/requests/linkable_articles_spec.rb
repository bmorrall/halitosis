require "spec_helper"

RSpec.describe "LinkableArticles", :rails, type: :request do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Schema.define do
      create_table :articles, force: true do |t|
        t.string :name
        t.integer :score
      end
    end
  end

  before do
    Article.create!(name: "Bravo", score: 2)
    Article.create!(name: "Alpha", score: 1)
    Article.create!(name: "Charlie", score: 3)
  end

  after do
    Article.delete_all
  end

  describe "GET /linkable_articles" do
    context "when no sort param is provided" do
      it "includes a self link with no query string" do
        get linkable_articles_path

        expect(response).to have_http_status(:ok)

        self_link = response.parsed_body.dig("_links", "self", "href")
        expect(self_link).to eq(linkable_articles_path)
      end
    end

    context "when a sort param is provided" do
      it "includes the sort param in the self link" do
        get linkable_articles_path, params: {sort: "name"}

        expect(response).to have_http_status(:ok)

        self_link = response.parsed_body.dig("_links", "self", "href")
        expect(self_link).to eq(linkable_articles_path(sort: "name"))
      end

      it "includes a descending sort param in the self link" do
        get linkable_articles_path, params: {sort: "-name"}

        expect(response).to have_http_status(:ok)

        self_link = response.parsed_body.dig("_links", "self", "href")
        expect(self_link).to eq(linkable_articles_path(sort: "-name"))
      end
    end
  end
end
