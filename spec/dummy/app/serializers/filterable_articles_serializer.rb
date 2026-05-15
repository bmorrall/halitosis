class FilterableArticlesSerializer
  include Halitosis

  collection :articles do
    articles.map { |article| ArticleSerializer.new(article) }
  end

  filterable_by :name do |value|
    collection.where(name: value)
  end

  filterable_by :score do |value|
    integer_value = Integer(value)
    collection.where(score: integer_value)
  rescue ArgumentError, TypeError
    nil
  end
end
