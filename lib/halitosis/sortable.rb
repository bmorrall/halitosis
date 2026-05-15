# frozen_string_literal: true

module Halitosis
  # Provides sort field declarations for collection serializers.
  #
  # Automatically included by Halitosis::Collection. Declare sort fields with
  # +sortable_by+ and optionally a +default_sort+ fallback applied when no sort
  # param is provided at render time.
  #
  module Sortable
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      attr_reader :default_sort_string, :default_sort_procedure

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
        fields.add(Sortable::Field.new(name, options, procedure))
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

        @default_sort_string = sort_string.to_s if sort_string
        @default_sort_procedure = procedure if procedure
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      # @return [Hash, Array] the rendered collection, sorted according to the sort param
      #
      def render_with_context(context)
        apply_sorts!(context)
        super
      end

      private

      # Validate that all requested sort field names are declared on this serializer.
      #
      # @param directives [Array<Array(String, Boolean)>] parsed sort directives
      #
      # @raise [Halitosis::InvalidQueryParameter] if an unknown sort field is requested
      #
      def validate_sorts!(directives)
        known_names = self.class.fields.for_type(Sortable::Field).map { |f| f.name.to_s }
        unknown = directives.map(&:first) - known_names

        return if unknown.none?

        raise_sort_error(unknown.first)
      end

      # Apply sort directives from context to @collection, or fall back to the
      # declared default sort if no sort param is present.
      #
      # @param context [Halitosis::Context] the render context
      #
      def apply_sorts!(context)
        sort_param = context.fetch(:sort, nil)
        directives = SortUtil.parse_sort_param(sort_param)

        if directives.empty?
          if (default_string = self.class.default_sort_string)
            directives = SortUtil.parse_sort_param(default_string)
          elsif (default_proc = self.class.default_sort_procedure)
            @collection = instance_exec(&default_proc)
            return
          else
            return
          end
        end

        return if directives.empty?

        validate_sorts!(directives)

        sort_fields = self.class.fields.for_type(Sortable::Field)

        directives.each do |name, ascending|
          field = sort_fields.find { |f| f.name.to_s == name }
          result = field.apply(self, ascending)

          if result.nil?
            sort_token = ascending ? name : "-#{name}"
            raise_sort_error(sort_token)
          end

          @collection = result
        end
      end

      # Build and raise an InvalidQueryParameter for the given sort token.
      #
      # @param sort_token [String] the sort token, e.g. "name" or "-name"
      #
      # @raise [Halitosis::InvalidQueryParameter]
      #
      def raise_sort_error(sort_token)
        resource_label = [self.class.resource_type, "collection"].compact.join(" ")
        raise Halitosis::InvalidQueryParameter.new(
          "The #{resource_label} can not be sorted by '#{sort_token}'",
          "sort"
        )
      end
    end
  end
end

require "halitosis/sort_util"
require "halitosis/sortable/field"
