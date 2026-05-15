class FilterableArticlesController < ApplicationController
  def index
    render renderable: FilterableArticlesSerializer.new(Article.all)
  end
end
