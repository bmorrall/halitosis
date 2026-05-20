class FilterableArticlesSerializer
  include Halitosis

  collection :articles do |articles|
    articles.map { |article| ArticleSerializer.new(article) }
  end

  filterable_by :name do |collection, value|
    collection.where(name: value)
  end

  filterable_by :score do |collection, value|
    integer_value = Integer(value)
    collection.where(score: integer_value)
  rescue ArgumentError, TypeError
    nil
  end

  link(:self) do |_, query_params|
    filterable_articles_path(query_params)
  end
end
