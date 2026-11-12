# frozen_string_literal: true

module Halitosis
  # JSON:API-style sideloading of included relationships.
  #
  # Included in every serializer by default. Included relationships are
  # replaced inline by a typed stub (+{id:, _type:}+) and their full payloads
  # are hoisted into a root-level +_included+ hash, grouped by resource type
  # and deduplicated by id.
  #
  # Serializers can enable +legacy_nesting!+, which additionally keeps the
  # full payload nested inline under +_relationships+ (merged with the typed
  # stub, so +_type+ is still present). The sideloaded records in +_included+
  # are unchanged: their relationships are always typed stubs.
  #
  # The root serializer decides the mode for the whole render tree.
  #
  module CollectIncludes
    def self.included(base)
      base.extend ClassMethods
      base.prepend InstanceMethods
    end

    module ClassMethods
      # Render included relationships nested inline (with +_type+) in addition
      # to sideloading them into +_included+.
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
          next if options[:parent]

          context.included_registry = {}
          context.legacy_nesting = legacy_nesting?
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
      # With legacy nesting, the child is also rendered inline with the typed
      # stub merged in. When no included registry is present on the context,
      # the child is only rendered inline.
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

        # Legacy nesting renders every occurrence inline with its own include
        # options, exactly as a nested render would.
        if context.legacy_nesting?
          child.before_render(child_context)
          payload = child.render_with_context(child_context)
        end

        hoist_child(child, context, [type, id_value], normalize_include_options(opts), payload)

        return stub unless payload

        stub.merge(payload).tap { |inline| context.legacy_stubs[inline] = stub }
      end

      private

      # Store the child's payload in the included registry, deduplicated by
      # +key+. A record that is already hoisted is only re-rendered when this
      # path asks for includes its stored payload does not cover (e.g.
      # +a.b.c,a.d.b.e+), using the merged include options.
      #
      # @param payload [Hash, nil] an inline render of the child with
      #   +requested+ include options, reused when it matches what is needed
      #
      def hoist_child(child, context, key, requested, payload)
        registry = context.included_registry
        rendered_opts = context.included_include_options

        if registry.key?(key)
          previous = rendered_opts.fetch(key, {})
          merged = HashUtil.deep_merge(previous, requested)
          return if merged == previous

          payload = nil unless merged == requested
          requested = merged
        end

        unless payload
          child_context = child.build_context(parent: context, include: requested)
          child.before_render(child_context)
          payload = child.render_with_context(child_context)
        end

        registry[key] = sideloaded(payload, context.legacy_stubs)
        rendered_opts[key] = requested
      end

      # Replace legacy inline relationships with their typed stubs, so
      # sideloaded records match a non-legacy render.
      #
      def sideloaded(value, legacy_stubs)
        return value if legacy_stubs.empty?

        case value
        when Hash
          legacy_stubs.fetch(value) { value.transform_values { |v| sideloaded(v, legacy_stubs) } }
        when Array
          value.map { |v| sideloaded(v, legacy_stubs) }
        else
          value
        end
      end

      # Normalize include options to nested hashes with string keys, treating
      # non-hash leaves (e.g. +true+, +1+) as having no further includes.
      #
      # @return [Hash]
      #
      def normalize_include_options(opts)
        return {} unless opts.is_a?(Hash)

        opts.each_with_object({}) { |(key, value), hash| hash[key.to_s] = normalize_include_options(value) }
      end

      def legacy_nesting?
        self.class.respond_to?(:legacy_nesting?) && self.class.legacy_nesting?
      end
    end
  end
end
