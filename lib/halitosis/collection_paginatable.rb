# frozen_string_literal: true

module Halitosis
  # Provides pagination for collection serializers.
  #
  # Automatically included by Halitosis::Collection. Declare pagination with
  # +paginate_by_page+, providing a required +default_page_size:+ and a 2-arity
  # block that receives +number+ (page number) and +size+ (items per page) and must return
  # the paginated collection.
  #
  # Pagination is driven by a nested +page:+ hash in the render context:
  #   +page[:number]+ — the 1-based page number (default: 1)
  #   +page[:size]+   — the number of items per page (default: +default_page_size+)
  #
  # This follows the JSON:API recommendation for pagination parameters
  # (+page[number]+ / +page[size]+).
  #
  module CollectionPaginatable
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
      base.send :include, CollectionPaginatable::Links
    end

    module ClassMethods
      # Low-level pagination hook for this collection serializer.
      #
      # The block receives +context+, the current +collection+, and a +page+
      # hash (+Hash+) as its arguments. +page+ is the value of +page:+ from the
      # render context (or an empty hash if absent). The block must return the
      # paginated collection.
      #
      # Prefer +paginate_by_page+ for the common page-number / page-size
      # strategy. Use +paginate_with+ when you need full control over how the
      # page hash is interpreted (e.g. cursor or offset pagination).
      #
      # @example
      #   paginate_with do |context, collection, page|
      #     collection.after(page[:cursor]).limit(page[:size] || 25)
      #   end
      #
      def paginate_with(&procedure)
        unless procedure
          raise InvalidField, "#{name} paginate_with must be defined with a block"
        end

        add_pagination_field(&procedure)
      end

      # Declare page-number / page-size pagination for this collection serializer.
      #
      # The block receives three arguments: +collection+, +number+ (Integer,
      # 1-based), and +size+ (Integer). It must return the paginated collection,
      # or +nil+ to signal that the provided values are invalid.
      #
      # +default_page_size+ is required and is used as the +size+ value when
      # none is provided at render time.
      #
      # @param default_page_size [Integer] the default number of items per page
      #
      # @example
      #   paginate_by_page default_page_size: 25 do |collection, number, size|
      #     collection.page(number).per(size)
      #   end
      #
      def paginate_by_page(default_page_size:, &procedure)
        unless procedure
          raise InvalidField, "#{name} paginate_by_page must be defined with a block"
        end

        add_pagination_field do |context, collection, page_params|
          number = parse_page_integer(page_params[:number], default: 1, param: :"page[number]")
          size = parse_page_integer(page_params[:size], default: default_page_size, param: :"page[size]")

          result = procedure.call(collection, number, size)

          context.register_query_params(page: {number: number, size: size})

          result
        end
      end

      # Declare Pagy-backed pagination for this collection serializer.
      #
      # With no block (recommended), paginates +collection+ automatically using
      # page number and size from the render context:
      #
      #   paginate_with_pagy
      #
      # Pass a block to supply extra options to +Pagy::Offset.new+. The block
      # receives the current +collection+ and the +page_params+ hash and must
      # return a kwargs hash:
      #
      #   paginate_with_pagy do |collection, page_params|
      #     { count: collection.published.count }
      #   end
      #
      # Filters and sorts declared on this serializer are applied to the collection
      # before pagination runs, keeping the full pipeline intact.
      #
      # The Pagy metadata is stored on the context and picked up automatically
      # by pagination metadata helpers.
      #
      def paginate_with_pagy(&procedure)
        add_pagination_field do |context, collection, page_params|
          extra_kwargs = procedure ? context.call_instance_with(collection, page_params, procedure) || {} : {}

          pagy_obj, records = CollectionPaginatable::PagyHelper.pagy(collection, page_params, **extra_kwargs)

          self.class.fields.singleton(CollectionPaginatable::MetadataField).process(context, pagy_obj)
          context.register_query_params(page: {number: pagy_obj.page, size: pagy_obj.limit})

          records
        end

        fields.add_singleton(CollectionPaginatable::MetadataField.new(CollectionPaginatable::Adapters::Pagy))
      end

      private

      def add_pagination_field(&block)
        if fields.singleton(CollectionPaginatable::Field)
          raise InvalidField, "#{name} pagination is already defined"
        end

        field = CollectionPaginatable::Field.new(:pagination, {}, block)
        fields.add_singleton(field)

        field
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      # @return [Hash, Array] the rendered collection, paginated according to
      #   the +page[:number]+ / +page[:size]+ values in the context
      #
      def render_with_context(context)
        apply_pagination!(context)
        super
      end

      private

      # Apply pagination to context.collection.
      #
      # @param context [Halitosis::Context] the render context
      #
      def apply_pagination!(context)
        field = self.class.fields.singleton(CollectionPaginatable::Field)
        return unless field

        if field.apply_pagination(context).nil?
          resource_label = [self.class.resource_type, "collection"].compact.join(" ")
          raise Halitosis::InvalidPaginationParameter,
            "The #{resource_label} can not be paginated with the provided values"
        end

        if (metadata_field = self.class.fields.singleton(CollectionPaginatable::MetadataField))
          metadata_field.process(context, context.collection) unless metadata_field.fetch_result(context)
        end
      end

      # Parse a value to a positive Integer, falling back to the default on nil.
      # Raises +InvalidPaginationParameter+ if the value is present but unparseable.
      #
      # @param value [String, Integer, nil]
      # @param default [Integer]
      # @param param [Symbol] the parameter name used in the error message
      # @return [Integer]
      #
      def parse_page_integer(value, default:, param:)
        return default if value.nil?

        Integer(value)
      rescue ArgumentError, TypeError
        raise_invalid_param_error(param)
      end

      # Raise an error for an unparseable pagination parameter.
      #
      # @param param [Symbol] the parameter name (e.g. +page[number]+ or +page[size]+)
      # @raise [Halitosis::InvalidPaginationParameter]
      #
      def raise_invalid_param_error(param)
        resource_label = [self.class.resource_type, "collection"].compact.join(" ")
        raise Halitosis::InvalidPaginationParameter.new(
          "The #{resource_label} can not be paginated with the provided '#{param}' value"
        )
      end

      protected

      private
    end
  end
end

require "halitosis/collection_paginatable/field"
require "halitosis/collection_paginatable/metadata_field"
require "halitosis/collection_paginatable/pagy_helper"
require "halitosis/collection_paginatable/adapters"
require "halitosis/collection_paginatable/links"
