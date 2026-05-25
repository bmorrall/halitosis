# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # A +RootMeta::Field+ subclass registered by +cursor_meta+ — one instance
    # per emitted key (+:next_cursor+ and/or +:prev_cursor+).
    #
    # +call_procedure+ reads the cursor value stored on the context by the
    # +CursorField+ outer procedure and returns it directly.
    #
    class CursorMetaKeyField < RootMeta::Field
      # Keys emitted by default when no +only:+ option is given.
      DEFAULT_KEYS = %i[next_cursor prev_cursor].freeze

      def self.registerable_as
        RootMeta::Field
      end

      def initialize(name, cursor_field)
        super(name, {}, nil)
        @cursor_field = cursor_field
      end

      private

      def call_procedure(context)
        case name
        when :next_cursor then @cursor_field.next_cursor(context)
        when :prev_cursor then @cursor_field.prev_cursor(context)
        end
      end
    end
  end
end
