# frozen_string_literal: true

module Halitosis
  module CollectIncludes
    def self.included(base)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with a root-level included array
      #
      def render(**options)
        # Stored on the instance rather than in options because options is frozen
        # and child contexts need to reach this via context.included_registry.
        @_collect_includes_registry = {}

        super.tap do |result|
          result[:included] = @_collect_includes_registry.values if @_collect_includes_registry.any?
        end
      ensure
        @_collect_includes_registry = nil
      end

      def collect_includes_registry
        @_collect_includes_registry
      end

      protected

      # Override render_child to stub children and hoist their full payloads
      # into the shared included registry. Recurses into nested relationships
      # by extending child instances with this module at render time.
      #
      # Falls back to super when:
      #   - no included registry is present on the context (not active)
      #   - the child has no Identifiers::Field defined
      #
      def render_child(child, context, opts)
        return super unless child.class.include?(Halitosis::Base)

        registry = context.included_registry
        return super unless registry

        # Collection primary items are data, not included relationships — render
        # them inline. But extend so their own render_child calls can hoist their
        # relationships into the shared registry.
        if collection?
          child.extend(CollectIncludes::InstanceMethods) unless child.is_a?(CollectIncludes::InstanceMethods)
          return super
        end

        id_field = child.class.fields.singleton(Identifiers::Field)
        return super unless id_field
        type = child.class.resource_type

        child_context = child.build_context(parent: context, include: opts)
        id_value = id_field.value(child_context)

        dedup_key = [type, id_value]

        unless registry.key?(dedup_key)
          # Extend so that any relationships this child renders are also stubbed
          child.extend(CollectIncludes::InstanceMethods) unless child.is_a?(CollectIncludes::InstanceMethods)
          registry[dedup_key] = child.render_with_context(child_context)
        end

        {id_field.name => id_value, :_type => type}
      end
    end
  end
end
