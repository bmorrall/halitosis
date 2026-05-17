class WillPaginateArticlesController < ApplicationController
  def index
    render renderable: WillPaginateArticlesSerializer.new(Article.all)
  end
end
