# frozen_string_literal: true

module Halitosis
  module Collection
    class Field < Halitosis::Field
      # Pass the working collection from the context as the first argument to
      # the proc, so blocks may optionally receive it: +do |collection| ... end+.
      # Zero-arity blocks (+do raw_collection end+) ignore the argument.
      #
      def value(context)
        options.fetch(:value) { context.call_instance(context.collection, procedure || name) }
      end

      # Returns the symbol key to use as the root envelope name, or +nil+ if
      # the root envelope should be omitted.
      #
      # When +:include_root+ is a String or Symbol it is used as the key;
      # when truthy, falls back to the field's own name;
      # when falsy, returns +nil+.
      #
      # @param context [Halitosis::Context]
      # @return [Symbol, nil]
      #
      def root_key(context)
        raw = context.fetch(:include_root) { context.depth.zero? }
        return nil unless raw

        (raw.is_a?(String) || raw.is_a?(Symbol)) ? raw.to_sym : name
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
