# frozen_string_literal: true

module Halitosis
  module RootLinks
    class Field < Halitosis::Links::Field
      private

      def call_procedure(context, _preloaded = nil)
        proc_or_name = procedure || name

        # :nocov:
        return context.call_instance(proc_or_name) unless proc_or_name.is_a?(Proc)
        # :nocov:

        context.call_instance_with(context, context.query_params, proc_or_name)
      end
    end
  end
end
