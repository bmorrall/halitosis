# frozen_string_literal: true

module Halitosis
  module Identifiers
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Rails-style identifier definition
      #
      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::Identifiers::Field]
      #
      def identifier(name, options = {}, &procedure)
        if fields.for_type(Field).any?
          raise InvalidField, "You can only define one identifier per serializer"
        end

        procedure ||= default_procedure_for(name) unless options.key?(:value)
        fields.add(Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with identifiers, if any
      #
      def render_with_context(context)
        super.merge(identifiers(context))
      end

      # @return [Hash] identifiers from fields
      #
      def identifiers(context = build_context)
        render_fields(Field, context) do |field, result|
          result[field.name] = field.value(context)
        end
      end
    end
  end
end

require "halitosis/identifiers/field"
