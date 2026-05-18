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

      # Pre-populate the preload cache for any enabled relationship fields
      # that declare a +preload:+ key. Fields sharing the same +preload_key+
      # are evaluated only once. Already-stored values are left untouched,
      # allowing callers to supply preloads manually before +render+ is called.
      #
      # @param context [Halitosis::Context]
      #
      def before_render(context)
        super

        self.class.fields.for_type(ResourceRelationships::Field).each do |field|
          next unless field.preload? && field.enabled?(context)

          fetch_preload(context, field.preload_key)
        end
      end

      # @return [Hash] hash of rendered resources to include
      #
      def relationships(context = build_context)
        # Do not validation non-root collections (as they pass values directly to children)
        validate_relationships!(context) unless collection?

        render_fields(ResourceRelationships::Field, context) do |field, result|
          # Use the preload cache if the field declares a preload: key, or if a
          # preload has already been stored for this key (e.g. manually via store_preload).
          # fetch_preload lazily evaluates and caches on first access.
          # Set preload: false to opt out of lazy loading (manually stored values are still used).
          preloaded = if field.preload? || preloaded?(context, field.preload_key)
            fetch_preload(context, field.preload_key)
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
