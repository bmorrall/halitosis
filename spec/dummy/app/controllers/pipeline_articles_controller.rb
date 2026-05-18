# frozen_string_literal: true

class PipelineArticlesController < ApplicationController
  def index
    render renderable: PipelineArticlesSerializer.new(Article.all)
  end
end
