# frozen_string_literal: true

module Halitosis
  module Filterable
    class Field < Halitosis::Field
      def validate
        super
        return true if procedure

        raise InvalidField, "Filter field #{name} must be defined with a proc"
      end

      def apply(instance, value)
        instance.instance_exec(value, &procedure)
      end
    end
  end
end
