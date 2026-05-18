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
        if fields.singleton(Identifiers::Field)
          raise InvalidField, "You can only define one identifier per serializer"
        end

        unless procedure
          source = options[:value].is_a?(Symbol) ? options.delete(:value) : name
          procedure = default_procedure_for(source) unless options.key?(:value)
        end
        fields.add_singleton(Identifiers::Field.new(name, options, procedure))
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
        field = self.class.fields.singleton(Identifiers::Field)
        return {} unless field&.enabled?(context)

        {field.name => field.value(context)}
      end
    end
  end
end

require "halitosis/identifiers/field"
