require "spec_helper"

RSpec.describe "PagyArticles", :pagy, :rails, type: :request do
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
    15.times { |i| Article.create!(name: "Article #{i + 1}", score: i + 1) }
  end

  after do
    Article.delete_all
  end

  describe "GET /pagy_articles" do
    context "when on the first page" do
      it "returns the first 20 articles with pagination meta and links", :aggregate_failures do
        get pagy_articles_path

        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["articles"].size).to eq(15)
        expect(body.dig("_meta", "first")).to eq(1)
        expect(body.dig("_meta", "last")).to eq(1)
        expect(body.dig("_meta", "prev")).to be_nil
        expect(body.dig("_meta", "next")).to be_nil
        expect(body.dig("_links", "first", "href")).to eq(pagy_articles_path(page: {number: 1}))
        expect(body.dig("_links", "last", "href")).to eq(pagy_articles_path(page: {number: 1}))
        expect(body.dig("_links", "prev")).to be_nil
        expect(body.dig("_links", "next")).to be_nil
      end
    end

    context "when requesting a specific page size" do
      it "returns the first page and correct meta and links", :aggregate_failures do
        get pagy_articles_path, params: {page: {size: 10}}

        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["articles"].size).to eq(10)
        expect(body.dig("_meta", "first")).to eq(1)
        expect(body.dig("_meta", "last")).to eq(2)
        expect(body.dig("_meta", "prev")).to be_nil
        expect(body.dig("_meta", "next")).to eq(2)
        expect(body.dig("_links", "first", "href")).to eq(pagy_articles_path(page: {number: 1}))
        expect(body.dig("_links", "last", "href")).to eq(pagy_articles_path(page: {number: 2}))
        expect(body.dig("_links", "prev")).to be_nil
        expect(body.dig("_links", "next", "href")).to eq(pagy_articles_path(page: {number: 2}))
      end
    end

    context "when on the second page" do
      it "returns the remaining articles with pagination meta and links", :aggregate_failures do
        get pagy_articles_path, params: {page: {number: 2, size: 10}}

        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["articles"].size).to eq(5)
        expect(body.dig("_meta", "first")).to eq(1)
        expect(body.dig("_meta", "last")).to eq(2)
        expect(body.dig("_meta", "prev")).to eq(1)
        expect(body.dig("_meta", "next")).to be_nil
        expect(body.dig("_links", "first", "href")).to eq(pagy_articles_path(page: {number: 1}))
        expect(body.dig("_links", "last", "href")).to eq(pagy_articles_path(page: {number: 2}))
        expect(body.dig("_links", "prev", "href")).to eq(pagy_articles_path(page: {number: 1}))
        expect(body.dig("_links", "next")).to be_nil
      end
    end
  end
end
