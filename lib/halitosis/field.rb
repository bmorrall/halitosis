# frozen_string_literal: true

module Halitosis
  # Stores instructions for how to render a value for a given serializer
  # instance
  #
  class Field
    attr_reader :name, :options

    attr_accessor :procedure

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

    # @param instance [Object] the serializer instance with which to evaluate
    #   the stored procedure
    #
    def value(instance)
      options.fetch(:value) do
        procedure ? instance.instance_eval(&procedure) : instance.send(name)
      end
    end

    # @return [true, false] whether this Field should be included based on
    #   its conditional guard, if any
    #
    def enabled?(instance)
      if options.key?(:if)
        !!eval_guard(instance, options.fetch(:if))
      elsif options.key?(:unless)
        !eval_guard(instance, options.fetch(:unless))
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

    # Evaluate guard procedure or method
    #
    def eval_guard(instance, guard)
      case guard
      when Proc
        instance.instance_eval(&guard)
      when Symbol, String
        instance.send(guard)
      else
        guard
      end
    end
  end
end
