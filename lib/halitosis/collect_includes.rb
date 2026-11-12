# frozen_string_literal: true

module Halitosis
  # JSON:API-style sideloading of included relationships.
  #
  # Included in every serializer by default. Included relationships are
  # replaced inline by a typed stub (+{id:, _type:}+) and their full payloads
  # are hoisted into a root-level +_included+ hash, grouped by resource type
  # and deduplicated by id.
  #
  # Serializers can opt out with +legacy_nesting!+, which keeps the full
  # payload nested inline under +_relationships+ (merged with the typed stub,
  # so +_type+ is still present) and omits +_included+.
  #
  # The root serializer decides the mode for the whole render tree.
  #
  module CollectIncludes
    def self.included(base)
      base.extend ClassMethods
      base.prepend InstanceMethods
    end

    module ClassMethods
      # Opt out of sideloading: render included relationships nested inline
      # (with +_type+) rather than hoisting them into +_included+.
      #
      # @return [void]
      #
      def legacy_nesting!
        @legacy_nesting = true
      end

      # @return [Boolean] whether legacy nesting is enabled
      #
      def legacy_nesting?
        return @legacy_nesting if defined?(@legacy_nesting)

        superclass.respond_to?(:legacy_nesting?) && superclass.legacy_nesting?
      end
    end

    module InstanceMethods
      def build_context(options = {})
        super.tap do |context|
          context.included_registry = {} unless options[:parent] || legacy_nesting?
        end
      end

      # @return [Hash] the rendered hash with a root-level included hash
      #
      def render_root(context, result)
        super.tap do |root|
          if context.included_registry && context.include_options.any?
            root[:_included] = context.included_registry.each_with_object({}) do |((type, _id), value), hash|
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
      # When no included registry is present on the context (legacy nesting),
      # the child is rendered inline with the typed stub merged in.
      #
      # Falls back to super when:
      #   - the child is not a Halitosis serializer
      #   - this serializer is a collection (primary items are rendered inline)
      #   - the child has no Identifiers::Field defined
      #
      def render_child(child, context, opts)
        return super unless child.class.include?(Halitosis::Base)

        # Extend so that any relationships this child renders follow the same mode
        child.extend(CollectIncludes::InstanceMethods) unless child.is_a?(CollectIncludes::InstanceMethods)

        # Collection primary items are data, not included relationships — render
        # them inline.
        return super if collection?

        id_field = child.class.fields.singleton(Identifiers::Field)
        return super unless id_field

        child_context = child.build_context(parent: context, include: opts)
        id_value = id_field.value(child_context)
        type = child.class.resource_type
        stub = {id_field.name => id_value, :_type => type}

        registry = context.included_registry
        unless registry
          child.before_render(child_context)
          return stub.merge(child.render_with_context(child_context))
        end

        dedup_key = [type, id_value]

        unless registry.key?(dedup_key)
          child.before_render(child_context)
          registry[dedup_key] = child.render_with_context(child_context)
        end

        stub
      end

      private

      def legacy_nesting?
        self.class.respond_to?(:legacy_nesting?) && self.class.legacy_nesting?
      end
    end
  end
end
