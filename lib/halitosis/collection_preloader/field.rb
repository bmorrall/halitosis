# frozen_string_literal: true

module Halitosis
  module CollectionPreloader
    # Stores a preload registration for a collection serializer.
    #
    # Used for both the default preload (+default_preload+) and path-specific
    # preloads (+preload+). The field name is the dot-joined include path, or
    # +"."+ for the default (no-path) preload.
    #
    class Field < Halitosis::Field
      attr_reader :path

      # @param path_array [Array<Symbol, String>] ordered relationship segments,
      #   e.g. +[:author, :avatar]+. Pass +[]+  for the default preload.
      # @param options [Hash] field options
      # @param procedure [Proc, nil] block applied to the collection
      #
      def initialize(path_array, options, procedure)
        @path = Array(path_array).map(&:to_sym)
        super(@path.empty? ? "." : @path.join("."), options, procedure)
      end

      # Apply the preload procedure to the current working collection.
      #
      # @param context [Halitosis::CollectionContext]
      # @return [Object, nil] the updated collection, or +nil+ if no procedure
      #
      def apply(context)
        return nil unless procedure

        context.call_instance(context.collection, procedure)
      end

      # @return [true]
      # @raise [Halitosis::InvalidField] if this is the default preload and no procedure was given
      #
      def validate
        raise InvalidField, "default_preload requires a block" if path.empty? && !procedure

        true
      end
    end
  end
end
