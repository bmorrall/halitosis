# frozen_string_literal: true

module Halitosis
  # Serializes a single exception to a JSON:API-style +{ errors: [...] }+ envelope
  # by wrapping it in a single-element array and delegating to +ErrorsSerializer+.
  #
  # Use +.build+ with the JSON:API DSL to define fields inline:
  #
  # @example
  #   render renderable: Halitosis::ExceptionSerializer.build(error) {
  #     code   { "unauthorized" }
  #     title  { "Unauthorized" }
  #     detail { error.message }
  #     source_header { "Authorization" }
  #     link(:about) { "https://docs.example.com/errors/unauthorized" }
  #   }, status: :unauthorized
  #
  # Or subclass +Halitosis::ErrorEntry+ for a reusable class:
  #
  # @example
  #   class AuthEntry < Halitosis::ErrorEntry
  #     code  { "unauthorized" }
  #     title { "Unauthorized" }
  #   end
  class ExceptionSerializer < ErrorsSerializer
    def self.build(exception, &dsl_block)
      raise ArgumentError, "#{name}.build requires a block" unless dsl_block

      entry_class = Class.new(Halitosis::ErrorEntry)
      entry_class.class_eval(&dsl_block)

      if entry_class.fields.empty?
        raise ArgumentError, "#{name}.build block must define at least one attribute, link, or meta field"
      end

      new(exception, error_serializer_class: entry_class)
    end

    def initialize(exception, error_serializer_class: Halitosis::ErrorEntry, **options)
      super([exception], param: nil, error_serializer_class: error_serializer_class, **options)
    end
  end
end
