# frozen_string_literal: true

module Halitosis
  module Collection
    class Field < Halitosis::Field
      # Pass the working collection from the context as the first argument to
      # the proc, so blocks may optionally receive it: +do |collection| ... end+.
      # Zero-arity blocks (+do raw_collection end+) ignore the argument.
      #
      def value(context)
        options.fetch(:value) { context.call_instance_with(context.collection, procedure || name) }
      end

      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        super

        return true if procedure

        raise InvalidField, "Collection #{name} must be defined with a proc"
      end
    end
  end
end
