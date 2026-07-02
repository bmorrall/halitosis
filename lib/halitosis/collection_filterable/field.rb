# frozen_string_literal: true

module Halitosis
  module CollectionFilterable
    class Field < Halitosis::Field
      def validate
        super
        if options.key?(:keys)
          keys = Array(options[:keys])
          if keys.empty? || keys.any? { |k| !k.is_a?(Symbol) && !k.is_a?(String) }
            raise InvalidField, "Filter field #{name} keys option must be a non-empty array of symbols"
          end
        end

        return true if procedure

        raise InvalidField, "Filter field #{name} must be defined with a proc"
      end

      def compound?
        Array(options[:keys]).any?
      end

      def compound_keys
        Array(options[:keys]).map(&:to_sym)
      end

      def typed?
        options.key?(:type)
      end

      # Cast +value+ using the declared type.
      # Supports any object responding to +cast+, or a symbol/string looked up
      # via +ActiveModel::Type+.
      #
      # @param value [Object] the raw filter value
      # @return [Object] the cast value, or +nil+ if the cast failed
      #
      def cast_value(value)
        resolve_type(options[:type]).cast(value)
      end

      # Cast each value in a compound filter hash using the declared type.
      #
      # @param hash [Hash] the symbolized compound filter hash
      # @return [Hash] new hash with each value cast; nil values are passed through
      #
      def cast_compound_hash(hash)
        type = resolve_type(options[:type])
        hash.transform_values { |v| v.nil? ? v : type.cast(v) }
      end

      def has_default?
        options.key?(:default)
      end

      # Resolve the default filter value in serializer instance context.
      # Supports Proc/lambda (called via instance_exec), Symbol (method call),
      # or any primitive (returned as-is).
      #
      # @param context [Halitosis::Context]
      # @return [Object] the resolved default value
      #
      def resolve_default(context)
        context.call_instance(options[:default])
      end

      def apply_filter(context, collection, value)
        if procedure.arity == 3
          errors = FilterErrors.new(name, prefix: (compound? ? name.to_s : nil))
          result = context.call_instance(collection, value, errors, procedure)
          [result, errors]
        else
          result = context.call_instance(collection, value, procedure)
          [result, nil]
        end
      rescue Halitosis::InvalidFilterParameter => e
        raise((e.parameter == "filter") ? Halitosis::InvalidFilterParameter.new(e.message, name) : e)
      end

      private

      def resolve_type(type_arg)
        return type_arg if type_arg.respond_to?(:cast)

        require "active_model/type"
        ActiveModel::Type.lookup(type_arg)
      end
    end
  end
end
