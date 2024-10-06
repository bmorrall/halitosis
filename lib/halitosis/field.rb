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
      @options = Halitosis::HashUtil.symbolize_hash(options).freeze
      @procedure = procedure
    end

    # @param context [Halitosis::Context] the serializer instance with which to evaluate
    #   the stored procedure
    #
    def value(context)
      options.fetch(:value) { context.call_instance(procedure || name) }
    end

    # @return [true, false] whether this Field should be included based on
    #   its conditional guard, if any
    #
    def enabled?(context)
      if options.key?(:if)
        !!context.call_instance(options.fetch(:if))
      elsif options.key?(:unless)
        !context.call_instance(options.fetch(:unless))
      else
        true
      end
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

    private

    attr_reader :procedure
  end
end
