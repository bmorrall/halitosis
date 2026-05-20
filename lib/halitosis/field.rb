# frozen_string_literal: true

module Halitosis
  # Stores instructions for how to render a value for a given serializer
  # instance
  #
  class Field
    attr_reader :name, :options

    # Construct a new Field instance
    #
    # @param name [Symbol, String] Field name
    # @param options [Hash] hash of options
    #
    # @return [Halitosis::Field] the instance
    #
    def initialize(name, options, procedure)
      @name = name.to_sym
      @options = Halitosis::HashUtil.symbolize_hash(options)
      @procedure = procedure
    end

    # @param context [Halitosis::Context] the serializer instance with which to evaluate
    #   the stored procedure
    #
    def value(context)
      options.fetch(:value) { call_procedure(context) }
    end

    # @return [true, false] whether this Field should be included based on
    #   its conditional guard, if any
    #
    def enabled?(context)
      context.call_conditional?(options)
    end

    # @return [true] if nothing is raised
    #
    # @raise [Halitosis::InvalidField] if the Field is invalid
    #
    def validate
      return true unless options.key?(:value) && procedure

      raise InvalidField,
        "Cannot specify both value and procedure for #{name}"
    end

    # The type under which this field registers in the fields collection.
    # Subclasses may override this to merge into a parent type's rendering bucket.
    def self.registerable_as
      self
    end

    private

    attr_reader :procedure

    def call_procedure(context)
      context.call_instance(procedure || name)
    end
  end
end
