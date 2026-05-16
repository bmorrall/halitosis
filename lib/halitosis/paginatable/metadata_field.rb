# frozen_string_literal: true

module Halitosis
  module Paginatable
    # Holds a metadata adapter for a collection serializer, providing normalised
    # pagination metadata (+current_page+, +total_pages+, etc.) to
    # +paginate_links+. Added automatically by +paginate_with_pagy+ and by
    # +paginate_links+ when an explicit adapter is supplied.
    #
    # Adapters respond to +call(instance, collection, context)+ and return a
    # normalised metadata hash, or +nil+ when metadata is unavailable.
    #
    class MetadataField
      attr_reader :adapter

      # @param adapter [#call] a callable that accepts (instance, collection, context)
      #
      def initialize(adapter)
        @adapter = adapter
      end

      # @param instance [Halitosis::Base] the serializer instance
      # @param context [Halitosis::Context] the render context
      # @return [Hash, nil]
      #
      def metadata(instance, context)
        adapter.call(instance, instance.collection, context)
      end

      # Store a value in the context local storage for later retrieval by
      # this field's adapter. Intended for adapters (such as Pagy) that require
      # data captured during pagination to be available at link-generation time.
      #
      # @param context [Halitosis::Context] the render context
      # @param value [Object] the value to store
      #
      def store_result(context, value)
        context.store_local(:paginatable_metadata_result, value)
      end

      # Retrieve a value previously stored via +store_result+.
      #
      # @param context [Halitosis::Context] the render context
      # @return [Object, nil]
      #
      def fetch_result(context)
        context.fetch_local(:paginatable_metadata_result)
      end

      # Returns the four navigational page numbers derived from the normalised
      # metadata. Keys are +:first+, +:last+, +:prev+, +:next+; unavailable
      # links (+prev+ on page 1, +next+ on last page) are +nil+.
      #
      # Returns +nil+ when the adapter returns no metadata.
      #
      # @param instance [Halitosis::Base] the serializer instance
      # @param context [Halitosis::Context] the render context
      # @return [Hash, nil]
      #
      def page_numbers(instance, context)
        m = metadata(instance, context)
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
    end
  end
end
