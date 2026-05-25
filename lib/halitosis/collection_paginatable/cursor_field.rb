# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # A singleton field registered by +paginate_by_cursor+ — there can be at
    # most one per serializer class.
    #
    # The stored +procedure+ is the outer lambda created by +paginate_by_cursor+.
    # It receives +(context, collection, page_params)+ via +apply_pagination+ and
    # returns the paginated collection (or +nil+ for invalid input).
    #
    # When the user's block returns a +Halitosis::CursorResult+, the result is
    # stored on the context so that +cursor_links+ and +cursor_meta+ can
    # retrieve the cursor values.
    #
    class CursorField < Halitosis::Field
      def initialize(name, options, procedure)
        super
      end

      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        raise InvalidField, "Cursor pagination #{name} must be defined with a proc" unless procedure

        true
      end

      # Call the outer procedure with page params and set the collection on the context.
      #
      # @param context [Halitosis::CollectionContext]
      # @return [Object, nil] the paginated collection, or +nil+ if the procedure
      #   returned nil (caller is responsible for raising)
      #
      def apply_pagination(context)
        page_params = context.fetch(:page, nil)
        page_params = {} unless page_params.is_a?(Hash)

        collection = context.call_instance(context, context.collection, page_params, procedure)
        return if collection.nil?

        context.collection = collection
      end

      # Returns the next cursor stored on the context after pagination.
      #
      # @param context [Halitosis::CollectionContext]
      # @return [String, nil]
      #
      def next_cursor(context)
        fetch_result(context)&.next_cursor
      end

      # Returns the previous cursor stored on the context after pagination.
      #
      # @param context [Halitosis::CollectionContext]
      # @return [String, nil]
      #
      def prev_cursor(context)
        fetch_result(context)&.prev_cursor
      end

      # Returns the +CursorResult+ stored on the context, or +nil+.
      #
      # @param context [Halitosis::CollectionContext]
      # @return [Halitosis::CursorResult, nil]
      #
      def fetch_result(context)
        context.fetch_local(:collection_cursor_result)
      end
    end
  end
end
