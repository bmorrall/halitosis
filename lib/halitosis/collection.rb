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
        raise InvalidCollection, "#{self.name} collection is already defined" if fields.key?(Field.name)

        self.resource_type = name.to_s

        alias_method name, :collection

        fields.add Field.new(name, options, procedure)
      end

      def collection?
        true
      end

      def collection_field
        fields[Field.name].last || raise(InvalidCollection, "#{name} collection is not defined")
      end
    end

    module InstanceMethods
      # Override standard initializer to assign primary collection
      #
      # @param collection [Object] the primary collection
      #
      def initialize(collection, **)
        @collection = collection

        super(**)
      end

      # @return [Hash, Array] the rendered hash with collection, as an array or a hash under a key
      #
      def render_with_context(context)
        field = self.class.collection_field
        if (include_root = context.fetch(:include_root) { context.depth.zero? })
          {
            root_name(include_root, self.class.resource_type) => render_collection_field(field, context)
          }.merge(super)
        else
          render_collection_field(field, context)
        end
      end

      def collection?
        true
      end

      private

      # @return [Hash] collection from fields
      #
      def render_collection_field(field, context)
        value = context.call_instance(field.procedure)

        return render_child(value, context, collection_opts(context)) if value.is_a?(Halitosis::Collection)

        value.reject { |child| child.is_a?(Halitosis::Collection) } # Skip nested collections in array
          .map { |child| render_child(child, context, collection_opts(context)) }
          .compact
      end

      def root_name(include_root, default)
        return include_root.to_sym if include_root.is_a?(String) || include_root.is_a?(Symbol)
        default.to_sym
      end

      # @param key [String]
      #
      # @return [Hash]
      #
      def collection_opts(context)
        return context.include_options if context.depth.positive?

        opts = context.include_options.fetch(self.class.collection_field.name.to_s, {})

        # Turn { :report => 1 } into { :report => {} } for child
        opts = {} unless opts.is_a?(Hash)

        opts
      end
    end
  end
end

require "halitosis/collection/field"
