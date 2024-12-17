class SimpleJsonsController < ApplicationController
  def index
    example = Simple.new(id: 1, name: "Simple 1")
    examples = [example]

    render json: SimplesSerializer.new(examples)
  end

  def show
    id_param = params[:id]
    example = Simple.new(id: id_param, name: "Simple #{id_param}")

    render json: SimpleSerializer.new(example)
  end
end
