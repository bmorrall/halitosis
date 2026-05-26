class TypedArticlesSerializer
  include Halitosis

  collection :articles do |articles|
    articles.map { |article| ArticleSerializer.new(article) }
  end

  filterable_by :score, :integer do |collection, value|
    collection.where(score: value)
  end

  filterable_by :published_on, :date do |collection, value|
    collection.where(published_on: value)
  end

  link(:self) do |_collection, query_params|
    typed_articles_path(query_params)
  end
end
