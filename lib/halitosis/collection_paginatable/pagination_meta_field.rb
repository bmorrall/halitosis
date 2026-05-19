# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Sentinel field whose presence in the fields registry indicates that
    # pagination page numbers should be emitted as +_meta+ keys at the root
    # level. Added automatically by +paginate_meta+.
    #
    # Contrast with +CollectionPaginatable::LinksField+, which builds URLs for
    # each page number. This field simply emits the raw integers (or +nil+).
    #
    class PaginationMetaField
      # Keys emitted by default when no +only:+ option is given.
      DEFAULT_KEYS = %i[self first last prev next].freeze

      def initialize(only: nil)
        @only = only
      end

      # Filter meta hash to only the requested keys.
      #
      # When no +only:+ option was given the default navigational keys
      # (+self+/+first+/+last+/+prev+/+next+) are returned. Pass +only:+ to select
      # any subset of the full available pool, which also includes
      # +current_page+, +per_page+, +total_entries+, and +total_pages+.
      #
      # @param meta [Hash]
      # @return [Hash]
      #
      def filter(meta)
        meta.slice(*Array(@only).map(&:to_sym))
      end

      # @return [true]
      def validate = true
    end
  end
end
