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

      def apply_filter(context, collection, value)
        if procedure.arity == 3
          errors = FilterErrors.new(name, prefix: (compound? ? name.to_s : nil))
          result = context.call_instance_with(collection, value, errors, procedure)
          [result, errors]
        else
          result = context.call_instance_with(collection, value, procedure)
          [result, nil]
        end
      end
    end
  end
end
