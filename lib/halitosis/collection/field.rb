# frozen_string_literal: true

module Halitosis
  module Collection
    class Field < Halitosis::Field
      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        super

        return true if procedure

        raise InvalidField, "Collection #{name} must be defined with a proc"
      end
    end
  end
end
