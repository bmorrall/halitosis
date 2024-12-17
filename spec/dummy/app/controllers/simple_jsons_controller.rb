class SimpleJsonsController < ApiController
  def index
    example = Example.new(id: 1, name: "Simple 1")
    examples = [example]

    render json: SimplesSerializer.new(examples).render_with_params(params)
  end

  def show
    id_param = params[:id]
    example = Example.new(id: id_param, name: "Simple #{id_param}")

    render json: SimpleSerializer.new(example).render_with_params(params)
  end
end
