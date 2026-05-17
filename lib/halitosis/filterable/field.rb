# frozen_string_literal: true

module Halitosis
  module Filterable
    class Field < Halitosis::Field
      def validate
        super
        return true if procedure

        raise InvalidField, "Filter field #{name} must be defined with a proc"
      end

      def apply_filter(context, value)
        context.call_instance_with(value, procedure)
      end
    end
  end
end
