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

      # Call the user procedure with page params and store the result on the context.
      #
      # @param context [Halitosis::Context]
      # @return [Object, nil] the paginated collection, or +nil+ if the procedure
      #   returned nil (caller is responsible for raising)
      #
      def apply_pagination(context)
        page_params = context.fetch(:page, nil)
        page_params = {} unless page_params.is_a?(Hash)

        collection = context.call_instance_with(context, context.collection, page_params, procedure)
        return if collection.nil?

        context.collection = collection
      end
    end
  end
end
