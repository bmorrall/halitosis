# frozen_string_literal: true

module Halitosis
  # Base module for all serializer classes.
  #
  # Include this module in your serializer class, and include any additional field-type modules
  module Base
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods

      base.send :attr_reader, :options
    end

    module ClassMethods
      # @return [Halitosis::Fields]
      def fields
        @fields ||= Fields.new
      end

      def collection?
        false
      end
    end

    module InstanceMethods
      # @param options [nil, Hash] hash of options
      #
      # @return [Object] the serializer instance
      #
      def initialize(**options)
        @options = Halitosis::HashUtil.symbolize_hash(options).freeze
      end

      # @return [Hash, Array] rendered JSON
      def as_json(...)
        render.as_json(...)
      end

      # @return [String] rendered JSON
      #
      def to_json(...)
        render.to_json(...)
      end

      # @return [Hash] rendered representation
      #
      def render
        render_with_context(build_context)
      end

      # @param context [Halitosis::Context] the context instance
      # @return [Hash] the rendered hash
      #
      def render_with_context(_context)
        {}
      end

      def collection?
        false
      end

      protected

      # Build a new context instance using this serializer instance
      #
      # @return [Halitosis::Context] the context instance
      def build_context(options = {})
        Context.new(self, HashUtil.deep_merge(@options, options))
      end

      # Allow included modules to decorate rendered hash
      #
      # @param key [Symbol] the key (e.g. `embedded`, `links`)
      # @param result [Hash] the partially rendered hash to decorate
      #
      # @return [Hash] the decorated hash
      #
      def decorate_render(key, context, result)
        result.tap do
          value = send(key, context)

          result[:"_#{key}"] = value if value.any?
        end
      end

      # Iterate through enabled fields of the given type, allowing instance
      # to build up resulting hash
      #
      # @param type [Symbol, String] the field type
      #
      # @return [Hash] the result
      #
      def render_fields(type, context)
        fields = self.class.fields.for_type(type)

        fields.each_with_object({}) do |field, result|
          next unless field.enabled?(context)

          yield field, result
        end
      end

      # @param child [Halitosis] the child serializer
      # @param opts [Hash] the include options to assign to the child
      #
      # @return [nil, Hash] the rendered child
      #
      def render_child(child, context, opts)
        return unless child.class.included_modules.include?(Halitosis::Base)

        child.render_with_context child.build_context(parent: context, include: opts)
      end
    end
  end
end
