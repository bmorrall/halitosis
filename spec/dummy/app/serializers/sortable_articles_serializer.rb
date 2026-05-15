class SortableArticlesSerializer
  include Halitosis

  collection :articles do
    articles.map { |article| ArticleSerializer.new(article) }
  end

  sortable_by :name do |ascending|
    collection.order(name: ascending ? :asc : :desc)
  end

  sortable_by :score do |ascending|
    collection.order(score: ascending ? :asc : :desc)
  end
end
