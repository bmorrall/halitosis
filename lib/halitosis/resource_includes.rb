# frozen_string_literal: true

module Halitosis
  # Provides a DSL for declaring which nested relationship include paths are
  # supported and how to enhance the preload cache when those paths are
  # requested. This prevents N+1 queries caused by nested collection includes.
  #
  # Automatically included by +Halitosis::Resource+.
  #
  # @example
  #   class ArticleSerializer
  #     include Halitosis
  #
  #     resource :article
  #
  #     relationship :accounts, preload: :accounts do |accounts|
  #       accounts.map { AccountSerializer.new(_1) }
  #     end
  #
  #     allow_include :accounts do
  #       allow_include :owner do |accounts|
  #         accounts.includes(:owner)
  #       end
  #     end
  #   end
  #
  module ResourceIncludes
    # Builder DSL context used to accumulate +allow_include+ field declarations
    # inside a builder block.
    #
    class Builder
      attr_reader :children, :preload_procedure

      def initialize
        @children = []
        @preload_procedure = nil
      end

      # Register a preload procedure for this builder scope. Applies when the
      # path represented by this builder is itself the deepest requested leaf.
      #
      # @param proc [Proc] receives the current cached value, returns the new value
      # @return [self]
      #
      def preload(proc)
        @preload_procedure = proc
        self
      end

      # Declare a supported nested include path.
      #
      # @param name [Symbol, String]
      # @param block [Proc, nil]
      #   - No block: leaf field with +DEFAULT_PROCEDURE+
      #   - Arity 1: leaf field using the block as the procedure
      #   - Arity 0: builder block; nested +allow_include+ and +preload+ calls
      #     configure the child
      #
      def allow_include(name, &block)
        field = if block.nil?
          ResourceIncludes::Field.new(name, nil, [])
        elsif block.arity == 1
          ResourceIncludes::Field.new(name, block, [])
        else
          sub_builder = Builder.new
          sub_builder.instance_eval(&block)
          ResourceIncludes::Field.new(name, sub_builder.preload_procedure, sub_builder.children)
        end

        @children << field

        field
      end
    end

    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Declare a supported top-level include path. The block must be a builder
      # block (arity 0) containing nested +allow_include+ declarations.
      #
      # @param name [Symbol, String] must match a declared +relationship+ name
      # @param block [Proc] builder block (required)
      #
      def allow_include(name, &block)
        builder = Builder.new

        builder.instance_eval(&block) if block

        fields.add(ResourceIncludes::Field.new(name, nil, builder.children))
      end
    end

    module InstanceMethods
      # Runs after +ResourceRelationships#before_render+ (via +super+). Finds
      # enabled include paths declared via +allow_include+, then applies each
      # matching field's procedure to the cached preload value for the root
      # relationship, composably replacing the cached value.
      #
      # @param context [Halitosis::Context]
      #
      def before_render(context)
        super

        process_resource_includes(context)
      end

      private

      def process_resource_includes(context)
        self.class.fields.for_type(ResourceIncludes::Field).each do |allow_field|
          nested_opts = context.include_options[allow_field.name.to_s]

          next unless nested_opts

          rel_field = find_relationship_field(allow_field.name)

          next unless rel_field&.enabled?(context)
          next if rel_field.options[:preload] == false

          cache_key = rel_field.preload_key

          traverse_include_tree(context, allow_field.children, nested_opts, cache_key)
        end
      end

      def traverse_include_tree(context, fields, include_opts, cache_key)
        fields.each do |field|
          child_opts = include_opts[field.name.to_s]

          next unless child_opts

          apply_include_procedure(context, field, cache_key)

          traverse_include_tree(context, field.children, child_opts, cache_key) if child_opts.any?
        end
      end

      def apply_include_procedure(context, field, cache_key)
        current = fetch_preload(context, cache_key)
        new_value = context.call_instance_with(current, field.procedure)

        preloads = context.fetch_local(:includeable_preloads) || {}
        context.store_local(:includeable_preloads, preloads.merge(cache_key.to_sym => new_value))
      end

      def find_relationship_field(name)
        self.class.fields
          .find_by_name(ResourceRelationships::Field, name)
      end
    end
  end
end

require "halitosis/resource_includes/field"
