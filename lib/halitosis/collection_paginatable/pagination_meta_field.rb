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
      # @return [true]
      def validate = true
    end
  end
end
