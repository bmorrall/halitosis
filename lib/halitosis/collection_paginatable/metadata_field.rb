# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Holds a metadata adapter for a collection serializer, providing normalised
    # pagination metadata (+current_page+, +total_pages+, etc.) for use by
    # +page_numbers+. Added automatically by +paginate_with_pagy+; also added
    # when an explicit adapter is registered at class definition time.
    #
    # Adapters respond to +call(raw)+ and return a normalised metadata hash,
    # or +nil+ when metadata is unavailable.
    #
    class MetadataField
      attr_reader :adapter

      # @param adapter [#call] a callable that accepts +raw+ and returns a normalised metadata hash
      #
      def initialize(adapter)
        @adapter = adapter
      end

      # @param context [Halitosis::Context] the render context
      # @return [Hash, nil]
      #
      def metadata(context)
        fetch_result(context)
      end

      # Normalize +raw+ via the adapter and store the result on the context.
      #
      # @param context [Halitosis::Context] the render context
      # @param raw [Object] the raw pagination object (e.g. a Pagy instance or
      #   paginated collection) to be normalized by the adapter
      #
      def process(context, raw)
        store_result(context, adapter.call(raw))
      end

      # Retrieve a value previously stored via +store_result+.
      #
      # @param context [Halitosis::Context] the render context
      # @return [Object, nil]
      #
      def fetch_result(context)
        context.fetch_local(:collection_paginatable_metadata_result)
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
          first: 1,
          last: m[:total_pages],
          prev: m[:prev_page],
          next: m[:next_page]
        }
      end

      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if no adapter was provided
      #
      def validate
        return true if adapter.respond_to?(:call)

        raise Halitosis::InvalidField, "Pagination metadata adapter must be callable"
      end

      private

      def store_result(context, value)
        context.store_local(:collection_paginatable_metadata_result, value)
      end
    end
  end
end
