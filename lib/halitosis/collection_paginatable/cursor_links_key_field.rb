# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # A +RootLinks::Field+ subclass registered by +cursor_links+ — one instance
    # per emitted key (e.g. +:prev+, +:next+).
    #
    # At render time, +call_procedure+ reads the cursor value stored on the
    # context by the +CursorField+ outer procedure and delegates to the
    # URL-building block supplied by the caller.
    #
    # Unavailable cursors (+nil+) are passed through to the block, which should
    # return +nil+ for unresolvable links. The +nil+ is then emitted as JSON
    # +null+ via +always_emit?+.
    #
    class CursorLinksKeyField < Halitosis::RootLinks::Field
      # Keys emitted by default when no +only:+ option is given.
      DEFAULT_KEYS = %i[prev next].freeze

      def self.registerable_as
        Halitosis::RootLinks::Field
      end

      def initialize(name, cursor_field, url_procedure)
        super(name, url_procedure)
        @cursor_field = cursor_field
      end

      # Always emit the key in +_links+, even when the value is +nil+.
      # This preserves the convention that navigational links are always
      # present, with +null+ indicating an unavailable link.
      #
      def always_emit?
        true
      end

      private

      def call_procedure(context, _preloaded = nil)
        cursor = name == :next ? @cursor_field.next_cursor(context) : @cursor_field.prev_cursor(context)
        context.call_instance(cursor, context.query_params, procedure)
      end
    end
  end
end
