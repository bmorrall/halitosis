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

      base.class.send :attr_accessor, :collection_name
    end

    module ClassMethods
      # @param name [Symbol, String] name of the collection
      #
      # @return [Module] self
      #
      def define_collection(name, options = {}, &procedure)
        raise InvalidCollection, "#{self.name} collection is already defined" if fields.key?(Field.name)

        self.collection_name = name.to_s

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
      def render
        field = self.class.collection_field
        if (include_root = options.fetch(:include_root) { depth.zero? })
          super.merge(root_name(include_root, field.name) => render_collection_field(field))
        else
          render_collection_field(field)
        end
      end

      # @return [Hash] collection from fields
      #
      def render_collection_field(field)
        value = instance_eval(&field.procedure)
        value.map { |child| render_child(child, collection_opts) }
      end

      def collection?
        true
      end

      private

      def root_name(include_root, default)
        return include_root.to_sym if include_root.is_a?(String) || include_root.is_a?(Symbol)
        default.to_sym
      end

      # @param key [String]
      #
      # @return [Hash]
      #
      def collection_opts
        return include_options if depth.positive?

        opts = include_options.fetch(self.class.collection_field.name.to_s, {})

        # Turn { :report => 1 } into { :report => {} } for child
        opts = {} unless opts.is_a?(Hash)

        opts
      end
    end
  end
end

require "halitosis/collection/field"
