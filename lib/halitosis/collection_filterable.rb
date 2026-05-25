# frozen_string_literal: true

module Halitosis
  module CollectionFilterable
    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Declare a named filter field, or open a nested namespace for grouping
      # related filter fields under a dot-prefixed key.
      #
      # When the block accepts +2+ arguments it is a filter implementation: the
      # block receives the current collection and the request value, and must
      # return the filtered collection, or +nil+ to signal an invalid value.
      #
      # When the block accepts +0+ arguments it opens a namespace. Calls to
      # +filterable_by+ inside the block are registered with a dot-prefixed name,
      # so both +filter[user][name]=Alice+ and +filter[user.name]=Alice+ map to
      # the same field.
      #
      # @param name [Symbol, String] the filter field name or namespace prefix
      # @param options [Hash] field options (e.g. +:if+, +:unless+); ignored for namespaces
      #
      # @example Field (arity 2)
      #   filterable_by :name do |collection, value|
      #     collection.where(name: value)
      #   end
      #
      # @example Namespace (arity 0)
      #   filterable_by :user do
      #     filterable_by :name do |collection, value|
      #       collection.joins(:user).where(users: { name: value })
      #     end
      #   end
      #
      def filterable_by(name, options = {}, &procedure)
        case procedure&.arity
        when 0
          CollectionFilterable::Namespace.new(name, self).instance_eval(&procedure)
        when 2, 3
          fields.add(CollectionFilterable::Field.new(name, options, procedure))
        when nil
          raise InvalidField, "Filter field #{name} must be defined with a proc"
        else
          raise InvalidField,
            "Filter field #{name} block must accept 0 arguments (namespace), " \
            "2 arguments (collection, filter value), or 3 arguments (collection, filter value, errors)"
        end
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      #
      def before_render(context)
        apply_filters!(context)
        super
      end

      private

      # Validate that all requested filter keys are declared on this serializer,
      # and that sub-keys of compound filters are among the declared keys.
      #
      # @param pairs [Array<Array(String, Object)>] parsed filter pairs
      #
      # @raise [Halitosis::InvalidFilterParameter] if an unknown filter key or sub-key is requested
      #
      def validate_filters!(pairs)
        known_names = self.class.fields.for_type(CollectionFilterable::Field).map { |f| f.name.to_s }
        unknown = pairs.map(&:first) - known_names

        raise_invalid_filter_parameter(unknown.first) if unknown.any?

        pairs.each do |name, value|
          field = self.class.fields.find_by_name(CollectionFilterable::Field, name)
          next unless field&.compound? && value.respond_to?(:each_pair)

          allowed = field.compound_keys.map(&:to_s)
          unknown_sub = value.keys.map(&:to_s) - allowed

          raise_invalid_filter_parameter("#{name}.#{unknown_sub.first}") if unknown_sub.any?
        end
      end

      # Apply filter pairs from context to @collection.
      #
      # @param context [Halitosis::Context] the render context
      #
      def apply_filters!(context)
        filter_param = context.fetch(:filter, nil)
        compound_names = self.class.fields.for_type(CollectionFilterable::Field)
          .select(&:compound?)
          .map { |f| f.name.to_s }
        pairs = FilterUtil.parse_filter_param(filter_param, compound_names: compound_names)

        return if pairs.empty?

        validate_filters!(pairs)

        context.register_query_params(filter: HashUtil.symbolize_hash(filter_param))

        pairs.each do |name, value|
          field = self.class.fields.find_by_name(CollectionFilterable::Field, name)
          resolved_value = (field.compound? && value.respond_to?(:transform_keys)) ? value.transform_keys(&:to_sym) : value

          result, errors = field.apply_filter(context, context.collection, resolved_value)

          if errors&.any?
            field_name, messages = errors.first
            raise_invalid_filter_parameter(field_name, messages.first)
          elsif result.nil?
            raise_invalid_filter_parameter(field.name, "The provided value is invalid.")
          end

          context.collection = result
        end
      end
    end
  end
end

require "halitosis/filter_util"
require "halitosis/collection_filterable/field"
require "halitosis/collection_filterable/namespace"
