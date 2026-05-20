# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Provides the +paginate_meta+ DSL for collection serializers, emitting
    # +first+/+last+/+prev+/+next+ page numbers as root-level +_meta+ keys
    # after pagination has been applied.
    #
    # Automatically included by +CollectionPaginatable+. Requires
    # +CollectionPaginatable+ to be present on the same class, as it relies on
    # the +CollectionPaginatable::Field+ singleton to obtain normalised page metadata regardless of
    # the pagination backend.
    #
    # == Usage
    #
    # Declare the adapter on the pagination method, then add +paginate_meta+:
    #
    #   paginate_by_page :kaminari, default_page_size: 25 do |collection, number, size|
    #     collection.page(number).per(size)
    #   end
    #
    #   paginate_meta
    #
    # The adapter may also be set globally:
    #
    #   Halitosis.configure { |c| c.pagination_adapter = :kaminari }
    #
    # == Output
    #
    # The rendered hash will contain a +_meta+ key at the root level with the
    # five navigational page numbers:
    #
    #   { _meta: { self: 2, first: 1, last: 5, prev: 1, next: 3 } }
    #
    # Unavailable links (+prev+ on page 1, +next+ on last page) are emitted as
    # +nil+ (serialised as JSON +null+).
    #
    # Pass +only:+ to select a custom subset of keys. The full available pool
    # also includes +current_page+, +per_page+, +total_entries+, and +total_pages+:
    #
    #   paginate_meta only: %i[current_page total_pages]
    #
    # == Combining with +paginate_links+
    #
    # +paginate_meta+ may be used alongside +paginate_links+ on the same
    # serializer. In that case, both +_links+ (URLs) and +_meta+ (page numbers)
    # are emitted.
    #
    module Meta
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        # Declare pagination page-number meta (+first+/+last+/+prev+/+next+)
        # for this collection serializer.
        #
        # The adapter must be declared on the pagination method itself (e.g.
        # +paginate_by_page :kaminari+ or +paginate_with :kaminari+), or set
        # globally via +Halitosis.config.pagination_adapter+. When using
        # +paginate_with_pagy+ the adapter is set automatically.
        #
        # @example
        #   paginate_meta
        #
        def paginate_meta(only: CollectionPaginatable::PaginationMetaKeyField::DEFAULT_KEYS)
          pagination_field = fields.singleton(CollectionPaginatable::Field)

          unless pagination_field
            raise InvalidField,
              "#{name} paginate_meta must be declared after paginate_by_page, " \
              "paginate_with, or paginate_with_pagy"
          end

          Array(only).each do |key|
            fields.add(CollectionPaginatable::PaginationMetaKeyField.new(key, pagination_field))
          end
        end
      end
    end
  end
end

require "halitosis/collection_paginatable/pagination_meta_key_field"
