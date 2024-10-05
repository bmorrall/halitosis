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
        fields.add(Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with attributes, if any
      #
      def render
        super.merge(attributes)
      end

      # @return [Hash] attributes from fields
      #
      def attributes
        render_fields(Field) do |field, result|
          result[field.name] = field.value(self)
        end
      end
    end
  end
end

require "halitosis/attributes/field"
