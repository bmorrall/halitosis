# frozen_string_literal: true

module Halitosis
  # Provides the +allow_include+ DSL for collection serializers to declare which
  # relationship include paths are accepted, and to optionally attach a preload
  # block that fires when those paths are requested.
  #
  # Blocks are arity-dispatched:
  #
  #   No block   — declaration only: registers the path as allowed with no preload.
  #
  #   Arity 0    — namespace block: +self+ inside the block is a +Builder+.
  #                Use +preload+ to attach a preload at this level, and nested
  #                +allow_include+ calls to declare deeper paths.
  #
  #   Arity 1    — runtime preload: the block receives the current collection and
  #                must return the preloaded collection.
  #
  # The preload walk fires the deepest registered field whose path is a prefix of
  # (or equal to) the requested leaf path. Each field fires at most once per render.
  #
  # @example Declaration only
  #   allow_include(:author)
  #
  # @example Flat declaration with preload
  #   allow_include(:author) { |coll| coll.includes(:author) }
  #
  # @example Namespace block with siblings
  #   allow_include(:author) do
  #     preload ->(coll) { coll.includes(:author) }
  #     allow_include(:avatar)  { |coll| coll.includes(author: :avatar) }
  #     allow_include(:summary) { |coll| coll.includes(author: :summary) }
  #   end
  #
  module CollectionIncludeable
    def self.included(base)
      base.extend ClassMethods

      base.send :include, CollectionPreloader

      base.send :include, EnforceAllowInclude

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
          fields.add(CollectionIncludeable::Field.new(path, {}, nil))
          CollectionIncludeable::Builder.new(path, self).instance_eval(&procedure)
        when 1
          fields.add(CollectionIncludeable::Field.new(path, {}, nil))
          preload(path, &procedure)
        when nil
          fields.add(CollectionIncludeable::Field.new(path, {}, nil))
        else
          raise InvalidField,
            "allow_include field #{name} block must accept 0 arguments (namespace) " \
            "or 1 argument (collection)"
        end

        nil
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      #
      def before_render(context)
        enforce_allow_include!(context) if self.class.enforce_allow_include?

        apply_preloads!(context)
        super
      end

      private

      # Raise +InvalidIncludeParameter+ for any requested include path that is
      # not backed by an +allow_include+ declaration. Walks the requested include
      # tree, requiring a declared +CollectionIncludeable::Field+ for every node.
      #
      # @param context [Halitosis::Context] the render context
      #
      def enforce_allow_include!(context)
        enforce_include_tree(context.include_options, [])
      end

      def enforce_include_tree(include_opts, prefix)
        include_opts.each_key do |name|
          path = prefix + [name.to_s]
          dotted = path.join(".")

          raise_invalid_include_parameter(dotted) unless self.class.fields.find_by_name(CollectionIncludeable::Field, dotted)

          nested = include_opts[name]
          enforce_include_tree(nested, path) if nested.is_a?(Hash) && nested.any?
        end
      end

      # Walk the include tree leaf-up and apply the deepest matching preload field for
      # each unique branch. A field is applied at most once per render, even when multiple
      # leaves share a common ancestor path.
      #
      # @param context [Halitosis::Context] the render context
      #
      def apply_preloads!(context)
        item_includes = context.include_options
        return if item_includes.empty?

        applied = []

        collect_leaf_paths(item_includes).each do |leaf_path|
          leaf_path.length.downto(1) do |len|
            candidate = leaf_path[0, len].join(".")
            next unless (field = self.class.fields.find_by_name(CollectionPreloader::Field, candidate))

            unless applied.include?(candidate)
              execute_collection_preload(context, field)
              applied << candidate
            end

            break
          end
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

require "halitosis/collection_includeable/field"
require "halitosis/collection_includeable/builder"
