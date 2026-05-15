# frozen_string_literal: true

module Halitosis
  module Attributes
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Legacy alias for attribute
      #
      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::Attributes::Field]
      def property(...)
        attribute(...)
      end

      # Rails-style attribute definition
      #
      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::Attributes::Field]
      #
      def attribute(name, options = {}, &procedure)
        unless procedure
          if options[:value].is_a?(Symbol)
            procedure = default_procedure_for(options.delete(:value))
          elsif !options.key?(:value)
            procedure = default_procedure_for(name)
          end
        end
        fields.add(Attributes::Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with attributes, if any
      #
      def render_with_context(context)
        super.merge(attributes(context))
      end

      # @return [Hash] attributes from fields
      #
      def attributes(context = build_context)
        render_fields(Attributes::Field, context) do |field, result|
          result[field.name] = field.value(context)
        end
      end
    end
  end
end

require "halitosis/attributes/field"
