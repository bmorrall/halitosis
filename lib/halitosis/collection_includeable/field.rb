# frozen_string_literal: true

module Halitosis
  module CollectionIncludeable
    class Field < Halitosis::Field
      # Default procedure used when no explicit procedure is provided.
      # Returns the collection unchanged, acting as a pass-through.
      #
      DEFAULT_PROCEDURE = ->(coll) { coll }

      attr_reader :path

      # @param path [Array<Symbol>] ordered list of relationship segments, e.g. [:author, :avatar]
      # @param options [Hash] field options
      # @param procedure [Proc, nil] optional runtime block; +nil+ registers the path as allowed
      #   with no preload behaviour.
      #
      def initialize(path, options, procedure)
        @path = path.map(&:to_sym)
        super(path.join("."), options, procedure)
      end

      # Apply the preload procedure to the collection held by the serializer instance.
      #
      # @param context [Halitosis::CollectionContext] the render context carrying the working collection
      #
      # @return [Object] the updated collection
      #
      def apply(context)
        context.call_instance(context.collection, procedure || DEFAULT_PROCEDURE)
      end
    end
  end
end
