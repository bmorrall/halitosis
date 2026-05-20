# frozen_string_literal: true

module Halitosis
  module CollectionFilterable
    class Field < Halitosis::Field
      def validate
        super
        return true if procedure

        raise InvalidField, "Filter field #{name} must be defined with a proc"
      end

      def apply_filter(context, collection, value)
        if procedure.arity == 3
          errors = FilterErrors.new(name)
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
