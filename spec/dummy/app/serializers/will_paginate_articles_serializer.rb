class WillPaginateArticlesSerializer
  include Halitosis

  collection :articles do |articles|
    articles.map { |article| ArticleSerializer.new(article) }
  end

  paginate_by_page(:will_paginate, default_page_size: 10) do |collection, number, size|
    collection.paginate(page: number, per_page: size)
  end

  paginate_links do |_, page_number, query_params|
    will_paginate_articles_path(query_params.merge(page: {number: page_number})) if page_number
  end

  paginate_meta
end
