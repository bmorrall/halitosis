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
  # Or subclass +ExceptionSerializer::ErrorEntry+ for a reusable class:
  #
  # @example
  #   class AuthEntry < Halitosis::ExceptionSerializer::ErrorEntry
  #     code  { "unauthorized" }
  #     title { "Unauthorized" }
  #   end
  class ExceptionSerializer < ErrorsSerializer
    # Alias to +ErrorSerializer::ClassMethods+ for backward compatibility.
    ClassMethods = ErrorSerializer::ClassMethods

    # Base Halitosis serializer for a single entry in the +errors+ array.
    # Carries the +ClassMethods+ DSL shortcuts. Subclass to build reusable
    # error entries, or use +ExceptionSerializer.build+ for inline definitions.
    class ErrorEntry
      include Halitosis
      extend ClassMethods

      required_option :error
    end

    def self.build(exception, &dsl_block)
      entry_class = Class.new(ErrorEntry)
      entry_class.class_eval(&dsl_block) if dsl_block
      new(exception, error_serializer_class: entry_class)
    end

    def initialize(exception, error_serializer_class: ErrorEntry, **options)
      super([exception], param: nil, error_serializer_class: error_serializer_class, **options)
    end
  end
end
