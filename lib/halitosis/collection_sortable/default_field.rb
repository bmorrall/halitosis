# frozen_string_literal: true

module Halitosis
  module CollectionSortable
    # Stores the default sort declaration for a collection serializer.
    # Accepts either a +sort_string+ (routed through the +sortable_by+ pipeline)
    # or a block receiving the current collection.
    #
    class DefaultField < Field
      attr_reader :sort_string

      def initialize(sort_string, procedure)
        @sort_string = sort_string
        @directives = SortUtil.parse_sort_param(sort_string) if sort_string
        super(:__default__, {}, procedure)
      end

      # Override: a DefaultField requires no procedure (sort_string is sufficient).
      #
      def validate
        true
      end

      # Override: for a sort_string, delegates each directive to the named
      # +sortable_by+ field. For a user block, calls the block with the collection.
      #
      # @param context [Halitosis::Context]
      # @param collection [Object]
      # @return [Object] the sorted collection
      #
      def apply_sort(context, collection, _ascending)
        if sort_string
          @directives.reduce(collection) { |coll, (name, ascending)|
            field = context.call_instance(proc { self.class.fields.find_by_name(CollectionSortable::Field, name) })
            raise Halitosis::InvalidSortParameter, "can not be sorted by '#{name}'" unless field

            field.apply_sort(context, coll, ascending)
          }
        else
          context.call_instance(collection, procedure)
        end
      end
    end
  end
end
