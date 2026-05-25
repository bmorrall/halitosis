# frozen_string_literal: true

require "halitosis/collection_paginatable/lazy_metadata"

module Halitosis
  module CollectionPaginatable
    # Built-in adapters for extracting pagination metadata from a paginated collection.
    #
    # Each adapter responds to +call(raw)+ and returns a +LazyMetadata+ wrapper:
    #
    #   metadata[:current_page]   # => Integer
    #   metadata[:total_pages]    # => Integer
    #   metadata[:prev_page]      # => Integer | nil
    #   metadata[:next_page]      # => Integer | nil
    #
    # Values are computed on first access, so expensive operations (e.g. a
    # SQL COUNT for +total_entries+) are only triggered when the key is
    # actually read during rendering.
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
      # Returns a +LazyMetadata+ wrapper around the collection. Each key is
      # evaluated on first access — in particular, +total_entries+ (which
      # triggers a SQL COUNT via +total_count+) is only called when actually read.
      #
      module Kaminari
        DEFINITIONS = {
          current_page: ->(c) { c.current_page },
          total_pages: ->(c) { c.total_pages },
          per_page: ->(c) { c.respond_to?(:limit_value) ? c.limit_value : nil },
          total_entries: ->(c) { c.respond_to?(:total_count) ? c.total_count : nil },
          prev_page: ->(c) { c.prev_page },
          next_page: ->(c) { c.next_page }
        }.freeze
        private_constant :DEFINITIONS

        def self.default_per_page_procedure
          ->(collection, number, size) { collection.page(number).per(size) }
        end

        def self.call(collection)
          return nil unless collection.respond_to?(:current_page) &&
            collection.respond_to?(:total_pages)

          LazyMetadata.new(collection, DEFINITIONS)
        end
      end

      # Adapter for WillPaginate-paginated collections.
      #
      # Returns a +LazyMetadata+ wrapper around the collection. Each key is
      # evaluated on first access — in particular, +total_entries+ is only
      # called when actually read.
      #
      module WillPaginate
        DEFINITIONS = {
          current_page: ->(c) { c.current_page },
          total_pages: ->(c) { c.total_pages },
          per_page: ->(c) { c.respond_to?(:per_page) ? c.per_page : nil },
          total_entries: ->(c) { c.respond_to?(:total_entries) ? c.total_entries : nil },
          prev_page: ->(c) { c.previous_page },
          next_page: ->(c) { c.next_page }
        }.freeze
        private_constant :DEFINITIONS

        def self.default_per_page_procedure
          ->(collection, number, size) { collection.paginate(page: number, per_page: size) }
        end

        def self.call(collection)
          return nil unless collection.respond_to?(:current_page) &&
            collection.respond_to?(:total_pages)

          LazyMetadata.new(collection, DEFINITIONS)
        end
      end

      # Adapter for Pagy-backed serializers.
      #
      # Receives the +Pagy+ object captured during +paginate_with_pagy+ and
      # returns a +LazyMetadata+ wrapper. Used automatically when you declare
      # +paginate_with_pagy+.
      #
      module Pagy
        DEFINITIONS = {
          current_page: ->(p) { p.page },
          total_pages: ->(p) { p.pages },
          per_page: ->(p) { p.limit },
          total_entries: ->(p) { p.count },
          prev_page: ->(p) { p.previous },
          next_page: ->(p) { p.next }
        }.freeze
        private_constant :DEFINITIONS

        def self.call(pagy)
          return unless pagy

          LazyMetadata.new(pagy, DEFINITIONS)
        end
      end
    end
  end
end
