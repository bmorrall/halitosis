# frozen_string_literal: true

RSpec.describe "Sparse fieldsets integration" do
  let(:article_resource_class) { Struct.new(:title, :body) }
  let(:author_resource_class) { Struct.new(:name, :email) }

  let(:author_class) do
    Class.new do
      include Halitosis

      resource :author

      attribute :name
      attribute :email
    end
  end

  let(:article_class) do
    author = author_class

    Class.new do
      include Halitosis

      resource :article

      attribute :title
      attribute :body
      attribute :published_at, value: "2026-01-01"

      relationship(:author) { author.new(Struct.new(:name, :email).new("Alice", "alice@example.com")) }
    end
  end

  def render_article(**options)
    article_class.new(Struct.new(:title, :body).new("Hello", "World"), **options).render
  end

  describe "single resource" do
    it "includes all attributes when no fields param is given" do
      result = render_article

      expect(result[:article]).to include(title: "Hello", body: "World", published_at: "2026-01-01")
    end

    it "includes only requested fields when fields matches the resource type" do
      result = render_article(fields: {article: "title,body"})

      expect(result[:article]).to include(title: "Hello", body: "World")
      expect(result[:article]).not_to have_key(:published_at)
    end

    it "includes all attributes when fields targets a different resource type" do
      result = render_article(fields: {people: "name"})

      expect(result[:article]).to include(title: "Hello", body: "World", published_at: "2026-01-01")
    end

    it "hides all attributes when an empty field list is given for the resource type" do
      result = render_article(fields: {article: ""})

      expect(result[:article]).not_to have_key(:title)
      expect(result[:article]).not_to have_key(:body)
      expect(result[:article]).not_to have_key(:published_at)
    end
  end

  describe "nested resource" do
    it "filters the nested resource's attributes independently" do
      result = render_article(
        include: "author",
        fields: {article: "title", author: "name"}
      )

      article = result[:article]
      expect(article).to include(title: "Hello")
      expect(article).not_to have_key(:body)

      author = article.dig(:_relationships, :author)
      expect(author).to include(name: "Alice")
      expect(author).not_to have_key(:email)
    end

    it "leaves the nested resource unfiltered when its type is not in the fields param" do
      result = render_article(
        include: "author",
        fields: {article: "title"}
      )

      author = result.dig(:article, :_relationships, :author)
      expect(author).to include(name: "Alice", email: "alice@example.com")
    end
  end
end
