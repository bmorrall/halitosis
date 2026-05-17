class PaginatableArticlesController < ApplicationController
  def index
    render renderable: PaginatableArticlesSerializer.new(Article.all)
  end
end
