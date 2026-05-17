class PaginatableArticlesSerializer
  include Halitosis

  collection :articles do |articles|
    articles.map { |article| ArticleSerializer.new(article) }
  end

  paginate_by_page(default_page_size: 10) do |collection, number, size|
    collection.offset((number - 1) * size).limit(size)
  end
end
