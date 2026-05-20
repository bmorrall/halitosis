# frozen_string_literal: true

module Halitosis
  module CollectionSortable
    class Field < Halitosis::Field
      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        super

        return true if procedure

        raise InvalidField, "Sort field #{name} must be defined with a proc"
      end

      # Apply the sort procedure to the given collection
      #
      # @param instance [Halitosis::Base] the serializer instance
      # @param ascending [Boolean] true for ascending, false for descending
      #
      # @return [Object] the sorted collection
      #
      def apply_sort(context, collection, ascending)
        context.call_instance(collection, ascending, procedure)
      end
    end
  end
end
