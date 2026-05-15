# frozen_string_literal: true

module Halitosis
  module Filterable
    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Declare a named filter field.
      #
      # The block receives the filter value from the request and must return
      # the filtered collection, or +nil+ to signal that the value is invalid.
      #
      # @param name [Symbol, String] the filter field name (used as the key in
      #   the +filter+ param, e.g. +filter[name]=Alice+)
      # @param options [Hash] field options (e.g. +:if+, +:unless+)
      #
      # @example
      #   filterable_by :name do |value|
      #     collection.where(name: value)
      #   end
      #
      def filterable_by(name, options = {}, &procedure)
        fields.add(Filterable::Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      # @return [Hash, Array] the rendered collection, filtered according to the filter param
      #
      def render_with_context(context)
        apply_filters!(context)
        super
      end

      private

      # Validate that all requested filter keys are declared on this serializer.
      #
      # @param pairs [Array<Array(String, Object)>] parsed filter pairs
      #
      # @raise [Halitosis::InvalidFilterParameter] if an unknown filter key is requested
      #
      def validate_filters!(pairs)
        known_names = self.class.fields.for_type(Filterable::Field).map { |f| f.name.to_s }
        unknown = pairs.map(&:first) - known_names

        return if unknown.none?

        raise_unknown_filter_error(unknown.first)
      end

      # Apply filter pairs from context to @collection.
      #
      # @param context [Halitosis::Context] the render context
      #
      def apply_filters!(context)
        filter_param = context.fetch(:filter, nil)
        pairs = FilterUtil.parse_filter_param(filter_param)

        return if pairs.empty?

        validate_filters!(pairs)

        filter_fields = self.class.fields.for_type(Filterable::Field)

        pairs.each do |name, value|
          field = filter_fields.find { |f| f.name.to_s == name }
          result = field.apply(self, value)

          if result.nil?
            raise_invalid_filter_value_error(field.name)
          end

          @collection = result
        end
      end

      # Raise an error for an unknown (user-supplied) filter key.
      # The key is sanitized before interpolation.
      #
      # @param raw_key [String] the unrecognised key from the request
      # @raise [Halitosis::InvalidFilterParameter]
      #
      def raise_unknown_filter_error(raw_key)
        safe_key = raw_key.to_s.gsub(/[^\w.]/, "")[0, 50]
        resource_label = [self.class.resource_type, "collection"].compact.join(" ")
        raise Halitosis::InvalidFilterParameter.new(
          "The #{resource_label} can not be filtered by '#{safe_key}'"
        )
      end

      # Raise an error when a declared filter field returns nil (invalid value).
      # The field name is a declared symbol so safe to interpolate directly.
      #
      # @param field_name [Symbol] the declared filter field name
      # @raise [Halitosis::InvalidFilterParameter]
      #
      def raise_invalid_filter_value_error(field_name)
        resource_label = [self.class.resource_type, "collection"].compact.join(" ")
        raise Halitosis::InvalidFilterParameter.new(
          "The #{resource_label} can not be filtered by '#{field_name}' with the provided value"
        )
      end
    end
  end
end

require "halitosis/filter_util"
require "halitosis/filterable/field"
