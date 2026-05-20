# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # A +RootMeta::Field+ subclass registered by +paginate_meta+ — one instance
    # per emitted key (e.g. +:first+, +:last+, +:prev+, +:next+, +:self+).
    #
    # +call_procedure+ reads the normalised pagination metadata already stored
    # on the context by +CollectionPaginatable::Field#process+ and returns the
    # value for its own key, or +nil+ when the adapter returned no metadata.
    #
    class PaginationMetaKeyField < RootMeta::Field
      # Keys emitted by default when no +only:+ option is given.
      DEFAULT_KEYS = %i[self first last prev next].freeze

      def self.registerable_as
        RootMeta::Field
      end

      def initialize(name, pagination_field)
        super(name, {}, nil)
        @pagination_field = pagination_field
      end

      private

      def call_procedure(context)
        page_nums = @pagination_field.page_numbers(context)
        return unless page_nums

        col_meta = @pagination_field.collection_meta(context)
        page_nums.merge(col_meta || {})[name]
      end
    end
  end
end
