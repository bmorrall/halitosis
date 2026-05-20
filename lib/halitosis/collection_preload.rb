# frozen_string_literal: true

module Halitosis
  # Provides a +preload_collection+ DSL for collection serializers that runs
  # a single block against the working collection immediately after
  # +build_context+ seeds it — before filtering, sorting, and pagination.
  #
  # Only fires for root-level renders. Nested collection serializers (depth > 0)
  # are skipped.
  #
  # @example
  #   preload_collection { |collection| collection.includes(:author) }
  #
  module CollectionPreload
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
      def preload_collection(&procedure)
        fields.add_singleton(CollectionPreload::Field.new(procedure))

        nil
      end
    end

    module InstanceMethods
      # @return [Halitosis::CollectionContext] context with preloaded collection
      #
      def build_context(options = {})
        super.tap do |ctx|
          next unless ctx.root?

          field = self.class.fields.singleton(CollectionPreload::Field)
          next unless field

          result = field.apply(ctx)
          ctx.collection = result unless result.nil?
        end
      end
    end
  end
end

require "halitosis/collection_preload/field"
