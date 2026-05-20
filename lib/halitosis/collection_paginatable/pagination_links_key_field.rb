# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # A +Links::Field+ subclass registered by +paginate_links+ — one instance
    # per emitted key (e.g. +:self+, +:first+, +:last+, +:prev+, +:next+).
    #
    # At render time, +call_procedure+ reads the normalised page numbers already
    # stored on the context by +CollectionPaginatable::Field#process+, looks up
    # the page number for its own key, and delegates to the URL-building
    # procedure supplied by the caller.
    #
    # Unavailable links (nil page numbers, e.g. +prev+ on page 1) skip the
    # block entirely and return +nil+, which is then emitted as JSON +null+ via
    # +always_emit?+.
    #
    class PaginationLinksKeyField < Halitosis::RootLinks::Field
      # Keys emitted by default when no +only:+ option is given.
      DEFAULT_KEYS = %i[self first last prev next].freeze

      def self.registerable_as
        Halitosis::RootLinks::Field
      end

      def initialize(name, pagination_field, url_procedure)
        super(name, url_procedure)
        @pagination_field = pagination_field
      end

      # Always emit the key in +_links+, even when the value is +nil+.
      # This preserves the HAL convention that navigational links are always
      # present, with +null+ indicating an unavailable page.
      #
      def always_emit?
        true
      end

      private

      def call_procedure(context, _preloaded = nil)
        page_nums = @pagination_field.page_numbers(context)
        return unless page_nums

        n = page_nums[name]
        return if n.nil?

        context.call_instance(n, context.query_params, procedure)
      end
    end
  end
end
