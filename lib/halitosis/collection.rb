# frozen_string_literal: true

module Halitosis
  # Behavior for serializers with a primary collection resource.
  #
  # The main reason to declare a collection is that the resource with that name
  # will always be included during rendering.
  #
  module Collection
    def self.included(base)
      raise InvalidCollection, "#{base.name} has already defined a resource" if base.included_modules.include?(Resource)

      base.extend ClassMethods

      base.send :include, InstanceMethods

      base.send :attr_reader, :collection
    end

    module ClassMethods
      # @param name [Symbol, String] name of the collection
      #
      # @return [Module] self
      #
      def define_collection(name, options = {}, &procedure)
        raise InvalidCollection, "#{self.name || Collection.name} collection is already defined" if fields.for_type(Field).any?

        self.resource_type = name.to_s

        alias_method name, :collection

        fields.add Field.new(name, options, procedure)
      end

      def collection?
        true
      end

      def collection_field
        fields.for_type(Field).last || raise(InvalidCollection, "#{name || Collection.name} collection is not defined")
      end
    end

    module InstanceMethods
      # Override standard initializer to assign primary collection
      #
      # @param collection [Object] the primary collection
      #
      def initialize(collection, **)
        @collection = collection
        @collection_field = self.class.collection_field

        super(**)
      end

      # @return [Hash, Array] the rendered hash with collection, as an array or a hash under a key
      #
      def render_with_context(context)
        if (include_root = context.fetch(:include_root) { context.depth.zero? })
          {
            root_name(include_root) => render_collection_field(context)
          }.merge(super)
        else
          render_collection_field(context)
        end
      end

      def collection?
        true
      end

      private

      attr_reader :collection_field

      # @return [Hash] collection from fields
      #
      def render_collection_field(context)
        value = collection_field.value(context)

        return render_child(value, context, context.include_options) if value.is_a?(Halitosis::Collection)

        value.reject { |child| child.is_a?(Halitosis::Collection) } # Skip nested collections in array
          .map { |child| render_child(child, context, context.include_options) }
          .compact
      end

      def root_name(include_root)
        return include_root.to_sym if include_root.is_a?(String) || include_root.is_a?(Symbol)

        self.class.resource_type.to_sym
      end
    end
  end
end

require "halitosis/collection/field"
