class PagyArticlesController < ApplicationController
  def index
    render renderable: PagyArticlesSerializer.new(Article.all)
  end
end
