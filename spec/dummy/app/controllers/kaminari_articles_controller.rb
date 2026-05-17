class KaminariArticlesController < ApplicationController
  def index
    render renderable: KaminariArticlesSerializer.new(Article.all)
  end
end
