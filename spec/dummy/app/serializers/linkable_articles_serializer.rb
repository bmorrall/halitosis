class LinkableArticlesSerializer
  include Halitosis

  collection :articles do |articles|
    articles.map { |article| ArticleSerializer.new(article) }
  end

  sortable_by :name do |collection, ascending|
    collection.order(name: ascending ? :asc : :desc)
  end

  link(:self) do |_collection, query_params|
    linkable_articles_path(query_params)
  end
end
