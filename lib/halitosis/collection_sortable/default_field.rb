# frozen_string_literal: true

module Halitosis
  module CollectionSortable
    # Stores the default sort declaration for a collection serializer.
    # Accepts either a +sort_string+ (routed through the +sortable_by+ pipeline)
    # or a no-argument procedure block for custom ordering.
    #
    class DefaultField < Field
      def initialize(sort_string, procedure)
        super(:__default__, {}, sort_string ? build_sort_string_procedure(sort_string) : procedure)
      end

      # Override: a DefaultField requires no procedure (sort_string is sufficient).
      #
      def validate
        true
      end

      # Override: delegates to the stored procedure via call_instance, ignoring
      # collection and ascending (default procs use the instance's own collection).
      #
      # @param context [Halitosis::Context]
      # @return [Object] the sorted collection
      #
      def apply_sort(context, collection, _ascending)
        context.call_instance_with(collection, context, procedure)
      end

      private

      def build_sort_string_procedure(sort_string)
        directives = SortUtil.parse_sort_param(sort_string)
        ->(collection, context) {
          directives.reduce(collection) { |coll, (name, ascending)| apply_sort(context, coll, name, ascending) }
        }
      end
    end
  end
end
