# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Built-in adapters for extracting pagination metadata from a paginated collection.
    #
    # Each adapter responds to +call(raw)+ and returns a normalised metadata hash:
    #
    #   { current_page: Integer, total_pages: Integer,
    #     prev_page: Integer | nil, next_page: Integer | nil }
    #
    # Returns +nil+ when the raw value does not respond to the expected methods,
    # so that pagination metadata is silently skipped when unavailable.
    #
    module Adapters
      BUILT_IN = {
        kaminari: :Kaminari,
        will_paginate: :WillPaginate
      }.freeze
      private_constant :BUILT_IN

      # Resolve an adapter from a symbol, a built-in name, or any callable.
      #
      # @param adapter [Symbol, #call]
      # @return [#call]
      # @raise [Halitosis::InvalidField] for unknown symbols
      #
      def self.resolve(adapter)
        return adapter if adapter.respond_to?(:call)

        const_name = BUILT_IN[adapter]

        unless const_name
          raise InvalidField,
            "Unknown pagination adapter #{adapter.inspect}. " \
            "Expected :kaminari, :will_paginate, or a callable."
        end

        const_get(const_name)
      end

      # Adapter for Kaminari-paginated collections.
      #
      # Reads +current_page+, +total_pages+, +prev_page+, and +next_page+
      # directly from the collection object.
      #
      module Kaminari
        def self.call(collection)
          return nil unless collection.respond_to?(:current_page) &&
            collection.respond_to?(:total_pages)

          {
            current_page: collection.current_page,
            total_pages: collection.total_pages,
            per_page: collection.respond_to?(:limit_value) ? collection.limit_value : nil,
            total_entries: collection.respond_to?(:total_count) ? collection.total_count : nil,
            prev_page: collection.prev_page,
            next_page: collection.next_page
          }
        end
      end

      # Adapter for WillPaginate-paginated collections.
      #
      # Reads +current_page+, +total_pages+, +previous_page+, and +next_page+
      # directly from the collection object.
      #
      module WillPaginate
        def self.call(collection)
          return nil unless collection.respond_to?(:current_page) &&
            collection.respond_to?(:total_pages)

          {
            current_page: collection.current_page,
            total_pages: collection.total_pages,
            per_page: collection.respond_to?(:per_page) ? collection.per_page : nil,
            total_entries: collection.respond_to?(:total_entries) ? collection.total_entries : nil,
            prev_page: collection.previous_page,
            next_page: collection.next_page
          }
        end
      end

      # Adapter for Pagy-backed serializers.
      #
      # Receives the +Pagy+ object captured during +paginate_with_pagy+ and
      # returns a normalised metadata hash. Used automatically when you declare
      # +paginate_with_pagy+.
      #
      module Pagy
        def self.call(pagy)
          return unless pagy

          {
            current_page: pagy.page,
            total_pages: pagy.pages,
            per_page: pagy.limit,
            total_entries: pagy.count,
            prev_page: pagy.previous,
            next_page: pagy.next
          }
        end
      end
    end
  end
end
