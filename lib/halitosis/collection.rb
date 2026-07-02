# frozen_string_literal: true

module Halitosis
  # Behavior for serializers with a primary collection resource.
  #
  # The main reason to declare a collection is that the resource with that name
  # will always be included during rendering.
  #
  module Collection
    def self.included(base)
      raise InvalidCollection, "#{base.name} has already defined a resource" if base.include?(Resource)

      base.extend ClassMethods

      base.send :include, InstanceMethods

      base.send :attr_reader, :raw_collection

      base.include CollectionPreloader
      base.include CollectionPaginatable
      base.include CollectionSortable
      base.include CollectionFilterable
      base.include CollectionIncludeable
    end

    module ClassMethods
      # @param name [Symbol, String] name of the collection
      #
      # @return [Module] self
      #
      def define_collection(name, options = {}, &procedure)
        raise InvalidCollection, "#{self.name || Collection.name} collection is already defined" if fields.singleton(Collection::Field)

        self.resource_type = name.to_s

        fields.add_singleton Collection::Field.new(name, options, procedure)
      end

      def collection?
        true
      end

      def collection_field
        fields.singleton(Collection::Field) || raise(InvalidCollection, "#{name || Collection.name} collection is not defined")
      end

      # Provide an alias for root_link
      def link(*, **, &)
        root_link(*, **, &)
      end

      # Provide an alias for root_meta
      def meta(*, **, &)
        root_meta(*, **, &)
      end

      # Provide an alias for root_permission
      def permission(*, **, &)
        root_permission(*, **, &)
      end
    end

    module InstanceMethods
      # Override standard initializer to assign primary collection
      #
      # @param collection [Object] the primary collection
      #
      def initialize(collection, **)
        @raw_collection = collection
        self.class.collection_field # raises InvalidCollection if not defined

        super(**)
      end

      # @return [Halitosis::CollectionContext] context seeded with the raw collection
      #
      def build_context(options = {})
        ctx = CollectionContext.new(self, HashUtil.deep_merge(@options, options))
        ctx.collection = @raw_collection
        ctx
      end

      # @return [Hash, Array] the rendered hash with collection, as an array or a hash under a key
      #
      def render_with_context(context)
        if (key = self.class.collection_field.root_key(context))
          {key => render_collection_field(context)}.merge(super)
        else
          render_collection_field(context)
        end
      end

      def collection?
        true
      end

      private

      # @return [Hash] collection from fields
      #
      def render_collection_field(context)
        value = self.class.collection_field.value(context)

        return render_child(value, context, context.include_options) if value.is_a?(Halitosis::Collection)

        value.reject { |child| child.is_a?(Halitosis::Collection) } # Skip nested collections in array
          .map { |child| render_child(child, context, context.include_options) }
          .compact
      end
    end
  end
end

require "halitosis/collection/field"
require "halitosis/collection_context"
