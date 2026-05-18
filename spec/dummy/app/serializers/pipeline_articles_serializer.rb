# frozen_string_literal: true

class PipelineArticlesSerializer
  include Halitosis

  collection :articles do |articles|
    articles.map { |article| ArticleSerializer.new(article) }
  end

  filterable_by :name do |collection, value|
    collection.where(name: value)
  end

  sortable_by :score do |collection, ascending|
    collection.order(score: ascending ? :asc : :desc)
  end

  paginate_by_page(:kaminari, default_page_size: 5) do |collection, number, size|
    collection.page(number).per(size)
  end

  # Sum of scores across ALL records — unaffected by filter/sort/pagination.
  meta(:total_score) { |_context| raw_collection.sum(:score) }

  # Sum of scores for the current page only — after filter, sort, and pagination.
  meta(:page_score) { |context| context.collection.to_a.sum(&:score) }
end
