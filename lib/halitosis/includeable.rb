# frozen_string_literal: true

module Halitosis
  # Registers the +include+ render param into the context's +query_params+ during rendering.
  #
  # Automatically included by Halitosis::Base so it is available on every
  # serializer. The module normalises the raw include value (String, Symbol,
  # Array, or Hash) to a comma-separated string and stores it via
  # +context.register_query_params+.
  #
  module Includeable
    def self.included(base)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      # @return [Hash] the rendered hash
      #
      def before_render(context)
        include_value = context.fetch(:include, nil)
        if (normalized = normalize_include_param(include_value))
          context.register_query_params(include: normalized)
        end
        super
      end

      private

      # Normalize an include param value to a comma-separated string.
      #
      # @param value [String, Symbol, Array, Hash, nil]
      # @return [String, nil]
      #
      def normalize_include_param(value)
        case value
        when String, Symbol
          s = value.to_s.strip
          s.empty? ? nil : s
        when Array
          paths = value.flat_map { |v| normalize_include_param(v) }.compact
          paths.empty? ? nil : paths.join(",")
        when Hash
          paths = expand_include_paths(value)
          paths.empty? ? nil : paths.join(",")
        end
      end

      # Recursively expand a nested include hash into dot-notation path strings.
      #
      # @param hash [Hash]
      # @param prefix [String, nil]
      # @return [Array<String>]
      #
      def expand_include_paths(hash, prefix = nil)
        hash.flat_map do |key, nested|
          full_key = prefix ? "#{prefix}.#{key}" : key.to_s
          if nested.is_a?(Hash) && !nested.empty?
            expand_include_paths(nested, full_key)
          else
            [full_key]
          end
        end
      end
    end
  end
end
