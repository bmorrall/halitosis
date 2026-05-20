class PagyArticlesSerializer
  include Halitosis

  collection :articles do |articles|
    articles.map { |article| ArticleSerializer.new(article) }
  end

  paginate_with_pagy

  paginate_links do |_, page_number, query_params|
    pagy_articles_path(query_params.merge(page: {number: page_number})) if page_number
  end

  paginate_meta
end
