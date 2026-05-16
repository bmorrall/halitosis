# frozen_string_literal: true

module Halitosis
  module Resource
    class Field < Halitosis::Field
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
    end
  end
end
