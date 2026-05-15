# frozen_string_literal: true

module Halitosis
  module CollectionIncludeable
    class Builder
      # @param path [Array<Symbol>] the path prefix for fields registered through this builder
      # @param target_class [Class] the serializer class on which fields are registered
      #
      def initialize(path, target_class)
        @path = path.map(&:to_sym)
        @target_class = target_class
      end

      # Declare a nested include path as allowed, and optionally attach a preload block.
      #
      # Arity 0: evaluates the block as a DSL scope on a child builder.
      # Arity 1: registers a field at the extended path with the given preload proc.
      # No block: declaration only — registers the path as allowed with no preload.
      #
      # @param name [Symbol, String] relationship name
      #
      # @return [Halitosis::CollectionIncludeable::Builder] child builder at the extended path
      #
      # @raise [Halitosis::InvalidField] for any other block arity
      #
      def allow_include(name, &procedure)
        child_path = path + [name.to_sym]

        case procedure&.arity
        when 0
          target_class.fields.add(CollectionIncludeable::Field.new(child_path, {}, nil))
          self.class.new(child_path, target_class).instance_eval(&procedure)
        when 1
          target_class.fields.add(CollectionIncludeable::Field.new(child_path, {}, procedure))
        when nil
          target_class.fields.add(CollectionIncludeable::Field.new(child_path, {}, nil))
        else
          raise InvalidField,
            "allow_include field #{child_path.join(".")} block must accept 0 arguments (namespace) " \
            "or 1 argument (preload)"
        end

        self.class.new(child_path, target_class)
      end

      # Register a preload implementation at the current path.
      #
      # @param proc [Proc] a lambda or proc that receives the subject and returns the preloaded result
      #
      # @return [self]
      #
      def preload(proc)
        target_class.fields.add(CollectionIncludeable::Field.new(path, {}, proc))
        self
      end

      private

      attr_reader :path, :target_class
    end
  end
end
