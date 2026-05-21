# frozen_string_literal: true

module Halitosis
  module Attributes
    class Field < Halitosis::Field
      # @return [true, false] whether this field is enabled given its conditional
      #   guard and any active JSON:API sparse fieldset on the context.
      #
      def enabled?(context)
        return false unless super

        allowed = context.fetch_local(:current_sparse_fields)
        allowed.nil? || allowed.include?(name.to_s)
      end
    end
  end
end
