# frozen_string_literal: true

module Halitosis
  module ResourceRelationships
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::ResourceRelationships::Field]
      #
      def relationship(name, options = {}, &procedure)
        fields.add(ResourceRelationships::Field.new(name, options, procedure))
      end

      alias_method :rel, :relationship
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with relationships resources, if any
      #
      def render_with_context(context)
        decorate_render :relationships, context, super
      end

      # Pre-populate the preload cache for all relationship fields that
      # declare a +preload:+ key. Each unique +preload_key+ is evaluated once
      # via +default_procedure_for+; the result is stored under the field's
      # own name so the rendering step can look it up directly by field name.
      #
      # @param context [Halitosis::Context]
      #
      def preload_context(context)
        preloads = {}

        self.class.fields.for_type(ResourceRelationships::Field).each do |field|
          next unless field.preload?(context)

          unless preloads.key?(field.preload_key)
            preloads[field.preload_key] = context.call_instance(self.class.default_procedure_for(field.preload_key))
          end

          value = preloads[field.preload_key]
          store_preload(context, field.name, value)
        end
      end

      # @return [Hash] hash of rendered resources to include
      #
      def relationships(context = build_context)
        # Do not validation non-root collections (as they pass values directly to children)
        validate_relationships!(context) unless collection?

        render_fields(ResourceRelationships::Field, context) do |field, result|
          # Use the preload cache if a value has been stored under the field name
          # (populated by preload_context or manually via store_preload).
          preloaded = if field.preload?(context) || preloaded?(context, field.name)
            fetch_preload(context, field.name)
          end
          value = field.value(context, preloaded)

          result[field.name] = relationships_child(field.name.to_s, context, value)
        end
      end

      # @return [nil, Hash, Array<Hash>] either a single rendered child
      #   serializer or an array of them
      #
      def relationships_child(key, context, value)
        return unless value

        opts = child_relationship_opts(key, context)

        if value.is_a?(Array)
          value.map { |item| render_child(item, context, opts) }.compact
        else
          render_child(value, context, opts)
        end
      end

      # @param key [String]
      #
      # @return [Hash]
      #
      def child_relationship_opts(key, context)
        opts = context.include_options.fetch(key, {})

        # Turn { :report => 1 } into { :report => {} } for child
        opts = {} unless opts.is_a?(Hash)

        opts
      end

      private

      def validate_relationships!(context)
        opts = context.include_options.keys.map(&:to_s)

        opts -= self.class.fields.for_type(Field).map { |field| field.name.to_s }

        return if opts.none?

        resource_label = [self.class.resource_type, "resource"].compact.join(" ")
        raise Halitosis::InvalidIncludeParameter.new("The #{resource_label} does not have a `#{opts.first}` relationship path.")
      end
    end
  end
end

require "halitosis/resource_relationships/field"
