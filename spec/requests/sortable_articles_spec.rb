require "spec_helper"

RSpec.describe "SortableArticles", :rails, type: :request do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Schema.define do
      create_table :articles, force: true do |t|
        t.string :name
        t.integer :score
      end
    end
  end

  # Three articles with deliberate name/score combinations:
  #   "Bravo"   score: 2
  #   "Alpha"   score: 1
  #   "Charlie" score: 2  (same score as Bravo, different name)
  #
  # This lets us verify:
  #   - single-field name sort (all unique names)
  #   - multi-field sort where a tie on score is broken by name direction
  before do
    Article.create!(name: "Bravo", score: 2)
    Article.create!(name: "Alpha", score: 1)
    Article.create!(name: "Charlie", score: 2)
  end

  after do
    Article.delete_all
  end

  describe "GET /sortable_articles" do
    context "when no sort param is provided" do
      it "returns HTTP 200 and all articles" do
        get sortable_articles_path

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["articles"].size).to eq(3)
      end
    end

    context "when sorting by a single field" do
      it "sorts by name ascending" do
        get sortable_articles_path, params: {sort: "name"}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        expect(names).to eq(%w[Alpha Bravo Charlie])
      end

      it "sorts by name descending" do
        get sortable_articles_path, params: {sort: "-name"}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        expect(names).to eq(%w[Charlie Bravo Alpha])
      end

      it "sorts by score ascending" do
        get sortable_articles_path, params: {sort: "score"}

        expect(response).to have_http_status(:ok)

        scores = response.parsed_body["articles"].map { |a| a["score"] }
        expect(scores).to eq([1, 2, 2])
      end
    end

    context "when sorting by multiple fields" do
      # AR chains ORDER BY clauses: .order(score: :asc).order(name: :asc)
      # generates: ORDER BY score ASC, name ASC
      it "sorts by score ascending then name ascending" do
        get sortable_articles_path, params: {sort: "score,name"}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        # Alpha(score=1), then Bravo(score=2, name=Bravo) before Charlie(score=2, name=Charlie)
        expect(names).to eq(%w[Alpha Bravo Charlie])
      end

      # AR chains ORDER BY clauses: .order(score: :asc).order(name: :desc)
      # generates: ORDER BY score ASC, name DESC
      it "sorts by score ascending then name descending" do
        get sortable_articles_path, params: {sort: "score,-name"}

        expect(response).to have_http_status(:ok)

        names = response.parsed_body["articles"].map { |a| a["name"] }
        # Alpha(score=1), then Charlie(score=2, name desc) before Bravo(score=2, name desc)
        expect(names).to eq(%w[Alpha Charlie Bravo])
      end
    end

    context "when given an unknown sort field" do
      it "returns 400 with an InvalidSortParameter error" do
        get sortable_articles_path, params: {sort: "unknown"}

        expect(response).to have_http_status(:bad_request)

        expect(response.parsed_body["errors"]).to match([
          {
            "id" => "invalid_sort_parameter",
            "title" => "Invalid Sort Parameter",
            "detail" => "The articles collection can not be sorted by 'unknown'",
            "source" => {"parameter" => "sort"}
          }
        ])
      end
    end
  end
end
