# frozen_string_literal: true

module Halitosis
  module RootLinks
    class Field < Halitosis::Links::Field
      private

      def call_procedure(context)
        proc_or_name = procedure || name

        return context.call_instance(proc_or_name) unless proc_or_name.is_a?(Proc)

        case proc_or_name.arity
        when 0
          context.call_instance_with(proc_or_name)
        when 1
          context.call_instance_with(context.query_params, proc_or_name)
        else
          context.call_instance_with(context, context.query_params, proc_or_name)
        end
      end
    end
  end
end
