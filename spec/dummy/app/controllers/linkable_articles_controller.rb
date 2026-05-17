class LinkableArticlesController < ApplicationController
  def index
    render renderable: LinkableArticlesSerializer.new(Article.all)
  end
end
