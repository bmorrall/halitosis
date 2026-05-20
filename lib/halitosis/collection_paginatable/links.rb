# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Provides the +paginate_links+ DSL for collection serializers, emitting
    # +self+/+first+/+last+/+prev+/+next+ links after pagination has been applied.
    #
    # Automatically included by +CollectionPaginatable+. Requires +CollectionPaginatable+ to be
    # present on the same class, as it relies on the +pagination_metadata+ hook
    # to obtain normalised page metadata regardless of the pagination backend.
    #
    # == Usage
    #
    # Declare the adapter on the pagination method, then add +paginate_links+
    # with a 2-arity block:
    #
    #   paginate_by_page :kaminari, default_page_size: 25 do |collection, number, size|
    #     collection.page(number).per(size)
    #   end
    #
    #   paginate_links do |page_number, query_params|
    #     articles_url(query_params.merge(page: { number: page_number }))
    #   end
    #
    # The adapter may also be set globally:
    #
    #   Halitosis.configure { |c| c.pagination_adapter = :kaminari }
    #
    # == Pagy Integration
    #
    # Use +paginate_with_pagy+ — the adapter is inferred automatically:
    #
    #   paginate_with_pagy
    #
    #   paginate_links do |page_number, query_params|
    #     articles_url(query_params.merge(page: { number: page_number }))
    #   end
    #
    module Links
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        # Declare pagination links (+self+/+first+/+last+/+prev+/+next+) for
        # this collection serializer.
        #
        # The block receives two arguments:
        #   +page_number+ — the target page number (Integer), or +nil+ when the
        #                   link is unavailable (+prev+ on page 1, +next+ on last page)
        #   +query_params+ — the active query params hash (sort, filter, page size, etc.)
        #
        # The block should return a URL string, or +nil+ for unavailable links.
        # All five keys (+self+, +first+, +last+, +prev+, +next+) are always present
        # in the output; unavailable links are emitted as JSON +null+.
        #
        # The adapter must be declared on the pagination method itself (e.g.
        # +paginate_by_page :kaminari+ or +paginate_with :kaminari+), or set
        # globally via +Halitosis.config.pagination_adapter+. When using
        # +paginate_with_pagy+ the adapter is set automatically.
        #
        # @example
        #   paginate_links do |page_number, query_params|
        #     articles_url(query_params.merge(page: { number: page_number }))
        #   end
        #
        def paginate_links(only: CollectionPaginatable::PaginationLinksKeyField::DEFAULT_KEYS, &procedure)
          unless procedure
            raise InvalidField, "#{name} paginate_links must be defined with a block"
          end

          unless procedure.arity == 2
            raise InvalidField,
              "#{name} paginate_links block must accept exactly 2 arguments (page_number, query_params)"
          end

          pagination_field = fields.singleton(CollectionPaginatable::Field)

          unless pagination_field
            raise InvalidField,
              "#{name} paginate_links must be declared after paginate_by_page, " \
              "paginate_with, or paginate_with_pagy"
          end

          Array(only).each do |key|
            fields.add(CollectionPaginatable::PaginationLinksKeyField.new(key, pagination_field, procedure))
          end
        end
      end
    end
  end
end

require "halitosis/collection_paginatable/pagination_links_key_field"
