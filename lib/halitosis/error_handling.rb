# frozen_string_literal: true

module Halitosis
  module ErrorHandling
    extend ActiveSupport::Concern

    included do
      rescue_from Halitosis::InvalidQueryParameter, with: :render_halitosis_error
    end

    private

    def render_halitosis_error(error)
      status = ActionDispatch::ExceptionWrapper.rescue_responses[error.class.name]
      render json: Halitosis::ParameterExceptionSerializer.new(error), status: status
    end
  end
end
