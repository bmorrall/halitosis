# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    class Field < Halitosis::Field
      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        return true if procedure

        raise InvalidField, "Pagination #{name} must be defined with a proc"
      end

      # Call the user procedure with page params, raise on nil, and store
      # the result on the context.
      #
      # @param context [Halitosis::Context]
      #
      def apply_pagination(context)
        page_params = context.fetch(:page, nil)
        page_params = {} unless page_params.is_a?(Hash)

        collection = context.call_instance_with(context, context.collection, page_params, procedure)

        if collection.nil?
          resource_label = [context.resource_type, "collection"].compact.join(" ")
          raise Halitosis::InvalidPaginationParameter,
            "The #{resource_label} can not be paginated with the provided values"
        end

        context.collection = collection
      end
    end
  end
end
