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
    # four navigational page numbers:
    #
    #   { _meta: { first: 1, last: 5, prev: 2, next: 4 } }
    #
    # Unavailable links (+prev+ on page 1, +next+ on last page) are emitted as
    # +nil+ (serialised as JSON +null+).
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

        base.send :include, InstanceMethods
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
        def paginate_meta
          if fields.singleton(CollectionPaginatable::PaginationMetaField)
            raise InvalidField, "#{name} pagination meta is already defined"
          end

          unless fields.singleton(CollectionPaginatable::Field)
            raise InvalidField,
              "#{name} paginate_meta must be declared after paginate_by_page, " \
              "paginate_with, or paginate_with_pagy"
          end

          fields.add_singleton(CollectionPaginatable::PaginationMetaField.new)
        end
      end

      module InstanceMethods
        # @param context [Halitosis::Context] the render context
        # @param result [Hash] the fully-enveloped render output
        # @return [Hash]
        #
        def render_root(context, result)
          super.tap { |root| apply_pagination_meta!(root, context) }
        end

        private

        # Inject pagination page numbers into the root +_meta+ of the result.
        #
        # Always emits all four keys (+first+, +last+, +prev+, +next+).
        # Unavailable pages (+prev+ on page 1, +next+ on last page) are set to
        # +nil+ (serialised as JSON +null+).
        # Silently returns when +paginate_meta+ has not been declared or when
        # the adapter returns no metadata (e.g. non-paginated render).
        #
        # @param result [Hash] the partially rendered result hash (mutated in place)
        # @param context [Halitosis::Context]
        #
        def apply_pagination_meta!(result, context)
          return unless self.class.fields.singleton(CollectionPaginatable::PaginationMetaField)

          page_numbers = extract_pagination_page_numbers(context)
          return if page_numbers.nil?

          result[:_meta] = result.fetch(:_meta, {}).merge(page_numbers)
        end

        # @param context [Halitosis::Context]
        # @return [Hash, nil]
        #
        def extract_pagination_page_numbers(context)
          metadata_field = self.class.fields.singleton(CollectionPaginatable::Field)
          metadata_field.page_numbers(context)
        end
      end
    end
  end
end

require "halitosis/collection_paginatable/pagination_meta_field"
