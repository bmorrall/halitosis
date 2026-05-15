# frozen_string_literal: true

module Halitosis
  module ErrorHandling
    extend ActiveSupport::Concern

    included do
      rescue_from Halitosis::InvalidQueryParameter, with: :render_halitosis_error
    end

    private

    def render_halitosis_error(error)
      render json: Halitosis::ParameterExceptionSerializer.new(error), status: :bad_request
    end
  end
end
