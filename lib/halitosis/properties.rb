# frozen_string_literal: true

module Halitosis
  module Properties
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Rails-style alias for property
      #
      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::Properties::Field]
      def attribute(...)
        property(...)
      end

      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::Properties::Field]
      #
      def property(name, options = {}, &procedure)
        fields.add(Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with properties, if any
      #
      def render
        super.merge(properties)
      end

      # @return [Hash] properties from fields
      #
      def properties
        render_fields(Field.name) do |field, result|
          result[field.name] = field.value(self)
        end
      end
    end
  end
end

require "halitosis/properties/field"
