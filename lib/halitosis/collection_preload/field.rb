# frozen_string_literal: true

module Halitosis
  module CollectionPreload
    class Field < Halitosis::Field
      def initialize(procedure)
        super(:__preload__, {}, procedure)
      end

      # Override: a procedure is always required.
      #
      def validate
        raise InvalidField, "preload_collection requires a block" unless procedure

        true
      end

      # Apply the preload procedure to the current collection.
      #
      # @param context [Halitosis::CollectionContext]
      # @return [Object] the updated collection
      #
      def apply(context)
        context.call_instance(context.collection, procedure)
      end
    end
  end
end
