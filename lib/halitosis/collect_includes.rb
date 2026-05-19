# frozen_string_literal: true

module Halitosis
  module CollectIncludes
    def self.included(base)
      base.prepend InstanceMethods
    end

    module InstanceMethods
      def build_context(options = {})
        super.tap do |context|
          context.included_registry = {} unless options[:parent]
        end
      end

      # @return [Hash] the rendered hash with a root-level included hash
      #
      def render_root(context, result)
        super.tap do |root|
          if context.included_registry && context.include_options.any?
            root[:included] = context.included_registry.each_with_object({}) do |((type, _id), value), hash|
              (hash[type.to_sym] ||= []) << value
            end
          end
        end
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
          child.before_render(child_context)
          registry[dedup_key] = child.render_with_context(child_context)
        end

        {id_field.name => id_value, :_type => type}
      end
    end
  end
end
