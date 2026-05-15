class SortableArticlesController < ApplicationController
  def index
    render renderable: SortableArticlesSerializer.new(Article.all)
  end
end
