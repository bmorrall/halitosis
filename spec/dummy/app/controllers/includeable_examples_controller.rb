class IncludeableExamplesController < ApplicationController
  def show
    example = Example.new(id: params[:id].to_i, name: "Example #{params[:id]}")

    render renderable: IncludeableExampleSerializer.new(example)
  end
end
