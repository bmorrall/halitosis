class ComplexRenderablesController < ApplicationController
  def show
    id_param = params[:id]
    example = Example.new(id: id_param, name: "Complex #{id_param}")

    render renderable: ComplexSerializer.new(example)
  end
end
