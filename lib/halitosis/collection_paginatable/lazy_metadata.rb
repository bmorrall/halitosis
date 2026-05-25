# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # A hash-like wrapper that computes pagination metadata values lazily,
    # evaluating each key's callable only on first access.
    #
    # This avoids triggering expensive operations (e.g. SQL COUNT queries) for
    # keys that are never read during rendering (e.g. when only +current_page+
    # and +total_pages+ are needed for navigation links).
    #
    # Adapters return a +LazyMetadata+ instance from +call+. Consumers access
    # values via +[]+, which delegates to the corresponding callable on the
    # source object and memoizes the result.
    #
    class LazyMetadata
      # @param source [Object] the raw object passed to the adapter
      #   (e.g. a Kaminari/WillPaginate collection or a Pagy instance)
      # @param definitions [Hash{Symbol => #call}] per-key callables that each
      #   accept +source+ and return the computed value
      def initialize(source, definitions)
        @source = source
        @definitions = definitions
        @cache = {}
      end

      # Retrieve the value for +key+, computing it on first access.
      #
      # @param key [Symbol]
      # @return [Object, nil]
      def [](key)
        return @cache[key] if @cache.key?(key)

        @cache[key] = @definitions.key?(key) ? @definitions[key].call(@source) : nil
      end

      # @param key [Symbol]
      # @return [Boolean]
      def key?(key)
        @definitions.key?(key)
      end

      # Materialise all values into a plain Hash.
      #
      # @return [Hash]
      def to_h
        @definitions.keys.each_with_object({}) { |k, h| h[k] = self[k] }
      end

      # @param other [Object]
      # @return [Boolean]
      def ==(other)
        case other
        when LazyMetadata then to_h == other.to_h
        when Hash then to_h == other
        else false
        end
      end
    end
  end
end
