# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Provides the +cursor_links+ DSL for collection serializers, emitting
    # +prev+/+next+ cursor-based links after pagination has been applied.
    #
    # Automatically included by +CollectionPaginatable+. Requires
    # +paginate_by_cursor+ to have been declared on the same class.
    #
    # == Usage
    #
    #   paginate_by_cursor default_size: 25 do |collection, after, _before, size|
    #     records = collection.after_cursor(after).first(size + 1)
    #     has_more = records.size > size
    #     records = records.first(size)
    #     Halitosis::CursorResult.new(records, next_cursor: has_more ? records.last.id.to_s : nil)
    #   end
    #
    #   cursor_links do |cursor, query_params|
    #     cursor ? articles_url(query_params.merge(page: { after: cursor })) : nil
    #   end
    #
    module CursorLinks
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        # Declare cursor-based navigation links (+prev+/+next+) for this
        # collection serializer.
        #
        # The block receives two arguments:
        #   +cursor+ — the opaque cursor string for this link, or +nil+ when
        #               the link is unavailable
        #   +query_params+ — the active query params hash (sort, filter, page size, etc.)
        #
        # The block should return a URL string, or +nil+ for unavailable links.
        # Both keys (+prev+, +next+) are always present in the output; unavailable
        # links are emitted as JSON +null+.
        #
        # @example
        #   cursor_links do |cursor, query_params|
        #     cursor ? articles_url(query_params.merge(page: { after: cursor })) : nil
        #   end
        #
        def cursor_links(only: CursorLinksKeyField::DEFAULT_KEYS, &procedure)
          unless procedure
            raise InvalidField, "#{name} cursor_links must be defined with a block"
          end

          unless procedure.arity == 2
            raise InvalidField,
              "#{name} cursor_links block must accept exactly 2 arguments (cursor, query_params)"
          end

          cursor_field = fields.singleton(CollectionPaginatable::CursorField)

          unless cursor_field
            raise InvalidField, "#{name} cursor_links must be declared after paginate_by_cursor"
          end

          Array(only).each do |key|
            fields.add(CollectionPaginatable::CursorLinksKeyField.new(key, cursor_field, procedure))
          end
        end
      end
    end
  end
end

require "halitosis/collection_paginatable/cursor_links_key_field"
