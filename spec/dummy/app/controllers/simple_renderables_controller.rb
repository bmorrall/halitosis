class SimpleRenderablesController < ApplicationController
  def index
    example = Example.new(id: 1, name: "Simple 1")
    examples = [example]

    render renderable: SimplesSerializer.new(examples)
  end

  def show
    id_param = params[:id]
    example = Example.new(id: id_param, name: "Simple #{id_param}")

    render renderable: SimpleSerializer.new(example)
  end
end
