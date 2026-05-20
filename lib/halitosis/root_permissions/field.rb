# frozen_string_literal: true

module Halitosis
  module RootPermissions
    class Field < Halitosis::Permissions::Field
      private

      def call_procedure(context)
        if context.collection? && procedure&.arity&.nonzero?
          context.call_instance(context.collection, procedure)
        else
          super
        end
      end
    end
  end
end
