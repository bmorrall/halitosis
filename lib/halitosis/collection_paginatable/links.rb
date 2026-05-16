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
    # Declare +paginate_links+ alongside a pagination method and provide a
    # 2-arity block:
    #
    #   paginate_links :kaminari do |page_number, query_params|
    #     articles_url(query_params.merge(page: { number: page_number }))
    #   end
    #
    # The adapter argument may be omitted when a global default is configured:
    #
    #   Halitosis.configure { |c| c.pagination_adapter = :kaminari }
    #
    # == Pagy Integration
    #
    # Use +paginate_with_pagy+ instead of +paginate_by_page+ when using Pagy.
    # The block must return +[pagy, records]+. The adapter is inferred
    # automatically and must not be passed to +paginate_links+:
    #
    #   paginate_with_pagy do
    #     pagy(collection)
    #   end
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
        # All four keys are always present in the output; unavailable links are
        # emitted as JSON +null+.
        #
        # @param adapter [Symbol, #call, nil] +:kaminari+, +:will_paginate+, or any
        #   callable. Omit when using +paginate_with_pagy+ (adapter inferred automatically)
        #   or when a global default is set via +Halitosis.config.pagination_adapter+.
        #   Must not be provided when +paginate_with_pagy+ is used.
        #
        # @example Using with Kaminari (global adapter configured)
        #   paginate_links do |page_number, query_params|
        #     articles_url(query_params.merge(page: { number: page_number }))
        #   end
        #
        # @example Using with a per-serializer adapter
        #   paginate_links :will_paginate do |page_number, query_params|
        #     articles_url(query_params.merge(page: { number: page_number }))
        #   end
        #
        def paginate_links(adapter = nil, &procedure)
          unless procedure
            raise InvalidField, "#{name} paginate_links must be defined with a block"
          end

          unless procedure.arity == 2
            raise InvalidField,
              "#{name} paginate_links block must accept exactly 2 arguments (page_number, query_params)"
          end

          if fields.singleton(CollectionPaginatable::MetadataField)&.adapter == CollectionPaginatable::Adapters::Pagy && adapter
            raise InvalidField,
              "#{name} paginate_links adapter must not be set when using paginate_with_pagy"
          end

          if fields.singleton(CollectionPaginatable::LinksField)
            raise InvalidField, "#{name} pagination links are already defined"
          end

          if adapter
            fields.add_singleton(CollectionPaginatable::MetadataField.new(CollectionPaginatable::Adapters.resolve(adapter)))
          elsif !fields.singleton(CollectionPaginatable::MetadataField)
            config_adapter = Halitosis.config.pagination_adapter

            unless config_adapter
              raise InvalidField,
                "#{name} paginate_links requires an adapter. " \
                "Pass one as an argument, set Halitosis.config.pagination_adapter, or use paginate_with_pagy."
            end

            fields.add_singleton(CollectionPaginatable::MetadataField.new(CollectionPaginatable::Adapters.resolve(config_adapter)))
          end

          fields.add_singleton(CollectionPaginatable::LinksField.new(:pagination_links, {}, procedure))
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

          links = page_numbers.transform_values { |n| links_field.apply(context, n, context.query_params) }

          result[:_links] = result.fetch(:_links, {}).merge(links)
        end

        # Obtain normalised pagination metadata for link generation.
        #
        # Asks the +CollectionPaginatable::MetadataField+ for metadata first (covers Pagy and any
        # custom metadata proc). Falls back to the adapter when no metadata proc
        # is configured. Raises +InvalidField+ when neither is available.
        #
        # @param context [Halitosis::Context]
        # @return [Hash, nil]
        #
        def extract_pagination_metadata(context)
          metadata_field = self.class.fields.singleton(CollectionPaginatable::MetadataField)
          metadata_field.page_numbers(context)
        end
      end
    end
  end
end

require "halitosis/collection_paginatable/links_field"
