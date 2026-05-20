# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    class Field < Halitosis::Field
      def initialize(name, options, procedure)
        super
      end

      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        raise InvalidField, "Pagination #{name} must be defined with a proc" unless procedure
        raise InvalidField, "Pagination metadata adapter must be callable" unless adapter.respond_to?(:call)

        true
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

        collection = context.call_instance(context, context.collection, page_params, procedure)
        return if collection.nil?

        context.collection = collection
      end

      # Normalize +raw+ via the adapter and store the result on the context.
      #
      # @param context [Halitosis::Context] the render context
      # @param raw [Object] the raw pagination object to be normalized by the adapter
      #
      def process(context, raw)
        store_result(context, adapter.call(raw))
      end

      # @param context [Halitosis::Context] the render context
      # @return [Hash, nil]
      #
      def metadata(context)
        fetch_result(context)
      end

      # Retrieve a value previously stored via +process+.
      #
      # @param context [Halitosis::Context] the render context
      # @return [Object, nil]
      #
      def fetch_result(context)
        context.fetch_local(:collection_paginatable_metadata_result)
      end

      # Returns collection metadata for use in +paginate_meta+.
      #
      # @param context [Halitosis::Context] the render context
      # @return [Hash, nil]
      #
      def collection_meta(context)
        m = metadata(context)
        return unless m

        {
          current_page: m[:current_page],
          per_page: m[:per_page] || context.query_params.dig(:page, :size),
          total_entries: m[:total_entries],
          total_pages: m[:total_pages]
        }
      end

      # Returns the four navigational page numbers derived from the normalised
      # metadata. Keys are +:first+, +:last+, +:prev+, +:next+; unavailable
      # links (+prev+ on page 1, +next+ on last page) are +nil+.
      #
      # Returns +nil+ when the adapter returns no metadata.
      #
      # @param context [Halitosis::Context] the render context
      # @return [Hash, nil]
      #
      def page_numbers(context)
        m = metadata(context)
        return unless m

        {
          self: m[:current_page],
          first: 1,
          last: m[:total_pages],
          prev: m[:prev_page],
          next: m[:next_page]
        }
      end

      private

      # @return [#call] the pagination metadata adapter
      #
      def adapter
        options[:adapter]
      end

      def store_result(context, value)
        context.store_local(:collection_paginatable_metadata_result, value)
      end
    end
  end
end
