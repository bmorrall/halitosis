# frozen_string_literal: true

module Halitosis
  module ResourceIncludes
    class Field
      # Default procedure used when no explicit procedure is provided.
      # Returns the value unchanged, acting as a pass-through.
      #
      DEFAULT_PROCEDURE = ->(value) { value }

      attr_reader :name, :procedure, :children

      # @param name [Symbol, String]
      # @param procedure [Proc, nil] called with the current cached value when
      #   this node is part of a matched include path; defaults to +DEFAULT_PROCEDURE+
      # @param children [Array<Field>]
      #
      def initialize(name, procedure, children)
        @name = name.to_sym
        @procedure = procedure || DEFAULT_PROCEDURE
        @children = children.dup.freeze
      end

      # @return [true]
      #
      def validate
        true
      end
    end
  end
end
