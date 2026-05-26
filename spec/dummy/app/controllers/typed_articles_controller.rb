class TypedArticlesController < ApplicationController
  def index
    render renderable: TypedArticlesSerializer.new(Article.all)
  end
end
