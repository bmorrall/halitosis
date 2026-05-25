# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Provides the +cursor_meta+ DSL for collection serializers, emitting
    # +next_cursor+ and +prev_cursor+ as root-level +_meta+ keys after
    # pagination has been applied.
    #
    # Automatically included by +CollectionPaginatable+. Requires
    # +paginate_by_cursor+ to have been declared on the same class.
    #
    # == Usage
    #
    #   paginate_by_cursor default_size: 25 do |collection, after, _before, size|
    #     # ...
    #     Halitosis::CursorResult.new(records, next_cursor: cursor)
    #   end
    #
    #   cursor_meta
    #
    # == Output
    #
    # The rendered hash will contain a +_meta+ key at the root level:
    #
    #   { _meta: { next_cursor: "abc123", prev_cursor: nil } }
    #
    # Pass +only:+ to emit a subset of keys:
    #
    #   cursor_meta only: %i[next_cursor]
    #
    module CursorMeta
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        # Declare cursor metadata (+next_cursor+/+prev_cursor+) for this
        # collection serializer.
        #
        # @example
        #   cursor_meta
        #
        def cursor_meta(only: CursorMetaKeyField::DEFAULT_KEYS)
          cursor_field = fields.singleton(CollectionPaginatable::CursorField)

          unless cursor_field
            raise InvalidField, "#{name} cursor_meta must be declared after paginate_by_cursor"
          end

          Array(only).each do |key|
            fields.add(CollectionPaginatable::CursorMetaKeyField.new(key, cursor_field))
          end
        end
      end
    end
  end
end

require "halitosis/collection_paginatable/cursor_meta_key_field"
