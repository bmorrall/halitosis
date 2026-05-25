# frozen_string_literal: true

module Halitosis
  # Provides sort field declarations for collection serializers.
  #
  # Automatically included by Halitosis::Collection. Declare sort fields with
  # +sortable_by+ and optionally a +default_sort+ fallback applied when no sort
  # param is provided at render time.
  #
  module CollectionSortable
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Declare a named sort field.
      #
      # The block receives a single Boolean argument: +true+ for ascending,
      # +false+ for descending. It must return the sorted collection.
      #
      # @param name [Symbol, String] the sort field name (used in the sort param)
      # @param options [Hash] field options (e.g. +:if+, +:unless+)
      #
      # @example
      #   sortable_by :name do |ascending|
      #     collection.order(name: ascending ? :asc : :desc)
      #   end
      #
      def sortable_by(name, options = {}, &procedure)
        fields.add(CollectionSortable::Field.new(name, options, procedure))
      end

      # Declare a default sort applied when no sort param is present.
      #
      # Accepts either a sort string (uses the same +sortable_by+ pipeline,
      # e.g. +"-name"+ for descending name sort) or a no-argument block.
      # Providing both raises +InvalidField+.
      #
      # @param sort_string [String, nil] a sort param string, e.g. +"name"+ or +"-name"+
      #
      # @example Using a sort string (delegates to an existing sortable_by field)
      #   default_sort "-name"
      #
      # @example Using a block for custom default ordering
      #   default_sort { collection.order(created_at: :desc) }
      #
      def default_sort(sort_string = nil, &procedure)
        if sort_string && procedure
          raise InvalidField, "#{name} default_sort cannot specify both a string and a block"
        end

        fields.add_singleton(DefaultField.new(sort_string, procedure)) if sort_string || procedure
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      #
      def before_render(context)
        apply_sorts!(context)
        super
      end

      private

      # Apply sort directives from context to @collection, or fall back to the
      # declared default sort if no sort param is present.
      #
      # @param context [Halitosis::Context] the render context
      #
      def apply_sorts!(context)
        sort_param = context.fetch(:sort, nil)
        directives = SortUtil.parse_sort_param(sort_param)

        if directives.empty?
          if (default_field = self.class.fields.singleton(CollectionSortable::DefaultField))
            context.collection = default_field.apply_sort(context, context.collection, nil)
          end
          return
        end

        directives.each do |name, ascending|
          context.collection = apply_sort(context, context.collection, name, ascending)
        end

        sort_string = directives.map { |name, asc| asc ? name : "-#{name}" }.join(",")
        context.register_query_params(sort: sort_string)
      end

      # Look up a declared sort field by name and apply it to +collection+.
      #
      # @param context [Halitosis::Context]
      # @param collection [Object]
      # @param name [String] the sort field name
      # @param ascending [Boolean]
      # @return [Object] the sorted collection
      #
      # @raise [Halitosis::InvalidSortParameter] if the field is unknown or returns nil
      #
      def apply_sort(context, collection, name, ascending)
        sort_token = ascending ? name : "-#{name}"
        field = self.class.fields.find_by_name(CollectionSortable::Field, name)
        raise_invalid_sort_parameter(sort_token) unless field

        result = field.apply_sort(context, collection, ascending)
        raise_invalid_sort_parameter(sort_token) if result.nil?

        result
      end
    end
  end
end

require "halitosis/sort_util"
require "halitosis/collection_sortable/field"
require "halitosis/collection_sortable/default_field"
