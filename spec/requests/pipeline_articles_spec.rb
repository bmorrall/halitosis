# frozen_string_literal: true

require "spec_helper"

RSpec.describe "PipelineArticles", :kaminari, :rails, type: :request do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Schema.define do
      create_table :articles, force: true do |t|
        t.string :name
        t.integer :score
      end
    end
  end

  # 10 articles: "Alpha" with scores 1,3,5,7,9 and "Beta" with scores 2,4,6,8,10.
  #
  # total_score (all records)        = 1+2+3+4+5+6+7+8+9+10 = 55
  #
  # After filter(name=Alpha)         → scores 1,3,5,7,9
  # After sort(-score, descending)   → scores 9,7,5,3,1
  # After paginate(page 1, size 2)   → scores 9,7
  #
  # page_score (current page)        = 9+7 = 16
  #
  before do
    [1, 3, 5, 7, 9].each { |s| Article.create!(name: "Alpha", score: s) }
    [2, 4, 6, 8, 10].each { |s| Article.create!(name: "Beta", score: s) }
  end

  after { Article.delete_all }

  describe "GET /pipeline_articles" do
    context "with filter, sort, and pagination applied together" do
      subject(:body) do
        get pipeline_articles_path,
          params: {filter: {name: "Alpha"}, sort: "-score", page: {number: 1, size: 2}}

        response.parsed_body
      end

      it "returns HTTP 200" do
        body
        expect(response).to have_http_status(:ok)
      end

      it "returns only the two articles on the current page" do
        expect(body["articles"].map { |a| a["score"] }).to eq([9, 7])
      end

      it "returns total_score summing all records regardless of pipeline" do
        expect(body.dig("_meta", "total_score")).to eq(55)
      end

      it "returns page_score summing only the records on the current page" do
        expect(body.dig("_meta", "page_score")).to eq(16)
      end
    end
  end
end
