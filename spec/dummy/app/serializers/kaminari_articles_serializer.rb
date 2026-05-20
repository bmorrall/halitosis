class KaminariArticlesSerializer
  include Halitosis

  collection :articles do |articles|
    articles.map { |article| ArticleSerializer.new(article) }
  end

  paginate_by_page(:kaminari, default_page_size: 10) do |collection, number, size|
    collection.page(number).per(size)
  end

  paginate_links do |_, page_number, query_params|
    kaminari_articles_path(query_params.merge(page: {number: page_number})) if page_number
  end

  paginate_meta
end
