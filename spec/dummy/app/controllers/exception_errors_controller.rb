class ExceptionErrorsController < ApplicationController
  def show
    exc = StandardError.new("Token is missing or invalid")

    render renderable: Halitosis::ExceptionSerializer.build(exc) {
      code { "unauthorized" }
      title { "Unauthorized" }
      detail { error.message }
      source_header { "Authorization" }
    }, status: :unauthorized
  end
end
