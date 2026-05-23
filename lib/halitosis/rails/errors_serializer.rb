# frozen_string_literal: true

module Halitosis
  # Serializes an ActiveModel::Errors collection to a JSON:API-style errors array.
  #
  # Override +error_serializer_class+ in a subclass to substitute a custom
  # +ErrorSerializer+ subclass with extra JSON:API fields (e.g. title, status).
  #
  # Use +.build+ with the JSON:API DSL to override or extend the default +code+,
  # +detail+, and +source+ pointer fields inline. The block is evaluated in the
  # context of an anonymous +ErrorSerializer+ subclass, so all defaults are
  # inherited and any field you redefine (e.g. +source_parameter+) replaces the
  # inherited one.
  #
  # @example Pass a model — param is inferred from the model class name
  #   render renderable: Halitosis::ErrorsSerializer.new(record)
  #
  # @example Pass an errors collection with an explicit param
  #   render renderable: Halitosis::ErrorsSerializer.new(record.errors, param: "article")
  #
  # @example Override the source with a query parameter instead of a pointer
  #   render renderable: Halitosis::ErrorsSerializer.build(record.errors, param: "article") {
  #     source_parameter { "filter[status]" }
  #   }, status: :unprocessable_entity
  class ErrorsSerializer
    include Halitosis::Base

    required_option :param

    def self.build(model_or_errors, **options, &dsl_block)
      raise ArgumentError, "#{name}.build requires a block" unless dsl_block

      entry_class = Class.new(Halitosis::ErrorSerializer)
      entry_class.class_eval(&dsl_block)

      new(model_or_errors, error_serializer_class: entry_class, **options)
    end

    def initialize(model_or_errors, **options)
      if model_or_errors.class.respond_to?(:model_name)
        @errors = model_or_errors.errors
        options = {param: model_or_errors.class.model_name.param_key, **options}
      else
        @errors = model_or_errors
      end
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
