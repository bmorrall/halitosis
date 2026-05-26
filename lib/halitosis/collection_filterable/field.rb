# frozen_string_literal: true

module Halitosis
  module CollectionFilterable
    class Field < Halitosis::Field
      def validate
        super
        if options.key?(:keys)
          keys = Array(options[:keys])
          if keys.empty? || keys.any? { |k| !k.is_a?(Symbol) && !k.is_a?(String) }
            raise InvalidField, "Filter field #{name} keys option must be a non-empty array of symbols"
          end
        end

        return true if procedure

        raise InvalidField, "Filter field #{name} must be defined with a proc"
      end

      def compound?
        Array(options[:keys]).any?
      end

      def compound_keys
        Array(options[:keys]).map(&:to_sym)
      end

      def has_default?
        options.key?(:default)
      end

      # Resolve the default filter value in serializer instance context.
      # Supports Proc/lambda (called via instance_exec), Symbol (method call),
      # or any primitive (returned as-is).
      #
      # @param context [Halitosis::Context]
      # @return [Object] the resolved default value
      #
      def resolve_default(context)
        context.call_instance(options[:default])
      end

      def apply_filter(context, collection, value)
        if procedure.arity == 3
          errors = FilterErrors.new(name, prefix: (compound? ? name.to_s : nil))
          result = context.call_instance(collection, value, errors, procedure)
          [result, errors]
        else
          result = context.call_instance(collection, value, procedure)
          [result, nil]
        end
      end
    end
  end
end
