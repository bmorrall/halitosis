# frozen_string_literal: true

module Halitosis
  # Serializes an ActiveModel::Errors collection to a JSON:API-style errors array.
  #
  # Override +error_serializer_class+ in a subclass to substitute a custom
  # +ErrorSerializer+ subclass with extra JSON:API fields (e.g. title, status).
  #
  # @example
  #   render renderable: Halitosis::ErrorsSerializer.new(record.errors, param: "article")
  class ErrorsSerializer
    include Halitosis::Base

    required_option :param

    def initialize(errors, **options)
      @errors = errors
      super(**options)
    end

    def render_in(view_context, **)
      view_context.render plain: render.to_json
    end

    def format
      :json
    end

    def render_with_context(context)
      {errors: errors.map { |error| render_child(error_serializer_class.new(error: error, param: param), context, {}) }}
    end

    private

    attr_reader :errors

    def error_serializer_class
      options.fetch(:error_serializer_class, Halitosis::ErrorSerializer)
    end
  end
end
