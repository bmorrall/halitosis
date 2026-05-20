# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Provides the +paginate_links+ DSL for collection serializers, emitting
    # +first+/+last+/+prev+/+next+ links after pagination has been applied.
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

        base.send :include, InstanceMethods
      end

      module ClassMethods
        # Declare pagination links (+first+/+last+/+prev+/+next+) for
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
        def paginate_links(only: CollectionPaginatable::LinksField::DEFAULT_KEYS, &procedure)
          unless procedure
            raise InvalidField, "#{name} paginate_links must be defined with a block"
          end

          unless procedure.arity == 3
            raise InvalidField,
              "#{name} paginate_links block must accept exactly 3 arguments (context, page_number, query_params)"
          end

          if fields.singleton(CollectionPaginatable::LinksField)
            raise InvalidField, "#{name} pagination links are already defined"
          end

          unless fields.singleton(CollectionPaginatable::Field)
            raise InvalidField,
              "#{name} paginate_links must be declared after paginate_by_page, " \
              "paginate_with, or paginate_with_pagy"
          end

          fields.add_singleton(CollectionPaginatable::LinksField.new(:pagination_links, {only: only}, procedure))
        end
      end

      module InstanceMethods
        # @param context [Halitosis::Context] the render context
        # @param result [Hash] the fully-enveloped render output
        # @return [Hash]
        #
        def render_root(context, result)
          super.tap { |root| apply_pagination_links!(root, context) }
        end

        private

        # Inject pagination links into the rendered result.
        #
        # Always emits all four keys (+first+, +last+, +prev+, +next+).
        # Unavailable links are set to +nil+ (serialised as JSON +null+).
        # Silently returns when no links procedure has been declared or when the
        # adapter returns no metadata (e.g. non-paginated render).
        #
        # @param result [Hash] the partially rendered result hash (mutated in place)
        # @param context [Halitosis::Context]
        #
        def apply_pagination_links!(result, context)
          links_field = self.class.fields.singleton(CollectionPaginatable::LinksField)
          return unless links_field

          page_numbers = extract_pagination_metadata(context)
          return if page_numbers.nil?

          page_numbers = links_field.filter_page_numbers(page_numbers)

          links = page_numbers.transform_values do |n|
            next if n.nil?

            url = links_field.apply(context, n, context.query_params)
            url && {href: url}
          end

          result[:_links] = result.fetch(:_links, {}).merge(links)
        end

        # Obtain normalised pagination metadata for link generation from
        # the +CollectionPaginatable::Field+ singleton.
        #
        # @param context [Halitosis::Context]
        # @return [Hash, nil]
        #
        def extract_pagination_metadata(context)
          metadata_field = self.class.fields.singleton(CollectionPaginatable::Field)
          metadata_field.page_numbers(context)
        end
      end
    end
  end
end

require "halitosis/collection_paginatable/links_field"
