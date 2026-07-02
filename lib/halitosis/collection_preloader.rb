# frozen_string_literal: true

module Halitosis
  # Provides preload DSL for collection serializers:
  #
  # +default_preload+ — registers a single block applied to the collection
  # during +build_context+, before filtering, sorting, and pagination. Only
  # fires for root-level renders.
  #
  # +preload+ — registers a block for a specific include path, applied lazily
  # by +CollectionIncludeable#apply_preloads!+ when that path is requested.
  #
  module CollectionPreloader
    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Declare a preload block applied to the collection immediately after
      # +build_context+ seeds it, before filtering, sorting, and pagination.
      #
      # The block receives the current collection and must return the updated
      # collection. Only fires for root-level renders.
      #
      # @return [nil]
      #
      # @raise [Halitosis::InvalidField] if no block is given, or if called twice
      #
      def default_preload(&procedure)
        if fields.find_by_name(CollectionPreloader::Field, ".")
          raise InvalidField, "default_preload is already defined"
        end

        fields.add(CollectionPreloader::Field.new([], {}, procedure))

        nil
      end

      # Register a preload block for the given include path.
      #
      # @param path_array [Array<Symbol, String>] ordered relationship segments,
      #   e.g. +[:author]+ or +[:author, :avatar]+
      # @param options [Hash] optional +if:+/+unless:+ conditions
      # @param procedure [Proc, nil] block applied to the collection; +nil+
      #   registers the path without a preload effect
      #
      # @return [nil]
      #
      def preload(path_array, **options, &procedure)
        name = path_array.map(&:to_sym).join(".")

        return if fields.find_by_name(CollectionPreloader::Field, name)

        fields.add(CollectionPreloader::Field.new(path_array, options, procedure))

        nil
      end
    end

    module InstanceMethods
      # @return [Halitosis::CollectionContext] context with preloaded collection
      #
      def build_context(options = {})
        super.tap do |ctx|
          next unless ctx.root?

          field = self.class.fields.find_by_name(CollectionPreloader::Field, ".")
          next unless field

          result = field.apply(ctx)
          ctx.collection = result unless result.nil?
        end
      end

      private

      # Execute a collection preload for the given field and update the
      # working collection in the context.
      #
      # @param context [Halitosis::CollectionContext]
      # @param field [CollectionPreloader::PathField]
      #
      def execute_collection_preload(context, field)
        result = field.apply(context)
        context.collection = result unless result.nil?
      end
    end
  end
end

require "halitosis/collection_preloader/field"
