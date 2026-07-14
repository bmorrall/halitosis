# frozen_string_literal: true

module Halitosis
  # Provides the +allow_include+ DSL for resource serializers to declare which
  # relationship include paths are accepted, and to optionally attach a preload
  # block that fires when those paths are requested.
  #
  # Blocks are arity-dispatched:
  #
  #   No block   — declaration only: registers the path as allowed with no preload.
  #                Top-level paths typically need no block since AR loads them on
  #                first access.
  #
  #   Arity 0    — namespace block: +self+ inside the block is a +Builder+.
  #                Use +preload+ to attach a preload at this level, and nested
  #                +allow_include+ calls to declare deeper paths.
  #
  #   Arity 1    — runtime preload: the block receives the current value of the
  #                top-level relationship (e.g. +resource.authors+) and must return
  #                the preloaded value. The returned value replaces what the
  #                relationship field would otherwise render.
  #
  # When +Halitosis.config.allow_undeclared_includes+ is +false+ and at least one
  # +allow_include+ has been declared, any requested include path not present in
  # the declared set raises +InvalidIncludeParameter+ at render time.
  #
  # The preload walk fires the deepest registered field whose path is a prefix of
  # (or equal to) the requested leaf path. Each field fires at most once per render.
  #
  # @example Declaration only (top-level — AR loads on access)
  #   allow_include(:authors)
  #
  # @example Namespace block with nested preload
  #   allow_include(:authors) do
  #     allow_include(:comments) { |authors| authors.includes(:comments) }
  #   end
  #
  module ResourceIncludeable
    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Declare an include path as allowed, and optionally attach a preload block.
      #
      # @param name [Symbol, String] top-level relationship name
      #
      # @return [nil]
      #
      # @raise [Halitosis::InvalidField] for unsupported block arities
      #
      def allow_include(name, &procedure)
        path = [name.to_sym]

        case procedure&.arity
        when 0
          fields.add(ResourceIncludeable::Field.new(path, {}, nil))
          ResourceIncludeable::Builder.new(path, self).instance_eval(&procedure)
        when 1
          fields.add(ResourceIncludeable::Field.new(path, {}, procedure))
        when nil
          fields.add(ResourceIncludeable::Field.new(path, {}, nil))
        else
          raise InvalidField,
            "allow_include field #{name} block must accept 0 arguments (namespace) " \
            "or 1 argument (preload)"
        end

        nil
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      # @return [Hash] rendered resource after preloads are applied
      #
      def render_with_context(context)
        apply_preloads!(context)
        super
      end

      private

      # Walk the include tree leaf-up and fire the deepest matching preload field for
      # each unique branch. A field is fired at most once per render, even when multiple
      # leaves share a common ancestor path. Each field evaluates its relationship,
      # passes the value to its preload block, and stores the result in the context
      # for injection during relationship rendering.
      #
      # @param context [Halitosis::Context] the render context
      #
      def apply_preloads!(context)
        item_includes = context.include_options
        return if item_includes.empty?

        validate_includes!(context)

        preload_fields = self.class.fields.for_type(ResourceIncludeable::Field)
        return if preload_fields.empty?

        applied = []

        collect_leaf_paths(item_includes).each do |leaf_path|
          leaf_path.length.downto(1) do |len|
            candidate = leaf_path[0, len].join(".")
            next unless (field = preload_fields.find { |f| f.name.to_s == candidate })

            unless applied.include?(candidate)
              field.apply(self, context)
              applied << candidate
            end

            break
          end
        end
      end

      # Validate that all requested include leaf paths are in the declared set.
      # A no-op when +allow_undeclared_includes+ is +true+ or no paths are declared.
      #
      # @param context [Halitosis::Context] the render context
      #
      # @raise [Halitosis::InvalidIncludeParameter] for any undeclared leaf path
      #
      def validate_includes!(context)
        return if Halitosis.config.allow_undeclared_includes
        return if self.class.fields.for_type(ResourceIncludeable::Field).empty?

        collect_leaf_paths(context.include_options).each do |leaf_path|
          next if self.class.fields.get_field(ResourceIncludeable::Field, leaf_path.join("."))

          resource_label = [self.class.resource_type, "resource"].compact.join(" ")

          raise Halitosis::InvalidIncludeParameter.new(
            "The #{resource_label} does not support the `#{leaf_path.join(".")}` include."
          )
        end
      end

      # Recursively collect all leaf-to-root paths from a nested include-options hash.
      # Each leaf is returned as an ordered array of string segments from root to leaf.
      #
      # @param hash [Hash] nested include options with string keys
      # @param prefix [Array<String>] accumulated path segments
      #
      # @return [Array<Array<String>>] list of leaf paths
      #
      def collect_leaf_paths(hash, prefix = [])
        return [prefix] if !hash.is_a?(Hash) || hash.empty?

        hash.flat_map { |key, subtree| collect_leaf_paths(subtree, prefix + [key]) }
      end

    end
  end
end

require "halitosis/resource_includeable/field"
require "halitosis/resource_includeable/builder"
