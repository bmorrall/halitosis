# frozen_string_literal: true

module Halitosis
  module Attributes
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Rails-style attribute definition
      #
      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::Attributes::Field]
      #
      def attribute(name, options = {}, &procedure)
        unless procedure
          source = options[:value].is_a?(Symbol) ? options.delete(:value) : name
          procedure = default_procedure_for(source) unless options.key?(:value)
        end
        fields.add(Attributes::Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [void]
      #
      def before_render(context)
        super

        fields_param = context.fetch(:fields, nil)
        if fields_param && (registry = FieldsUtil.build_registry(fields_param))
          normalized = registry.to_h { |type, set| [type.to_sym, set.to_a.sort.join(",")] }
          context.register_query_params(fields: normalized)
          context.sparse_fields_registry = registry
        end
      end

      # @return [Hash] the rendered hash with attributes, if any
      #
      def render_with_context(context)
        if (rt = self.class.resource_type) && (registry = context.sparse_fields_registry)
          context.store_local(:current_sparse_fields, registry[rt.to_s] || registry[rt.to_sym])
        end

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
