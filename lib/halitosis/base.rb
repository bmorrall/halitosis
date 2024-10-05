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
        @options = Halitosis::HashUtil.symbolize_hash(options)
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
        {}
      end

      # @return [nil, Object] the parent serializer, if this instance is an
      #   embedded child
      #
      def parent
        @parent ||= options.fetch(:parent, nil)
      end

      # @return [Integer] the depth at which this serializer is embedded
      #
      def depth
        @depth ||= parent ? parent.depth + 1 : 0
      end

      def collection?
        false
      end

      protected

      # Allow included modules to decorate rendered hash
      #
      # @param key [Symbol] the key (e.g. `embedded`, `links`)
      # @param result [Hash] the partially rendered hash to decorate
      #
      # @return [Hash] the decorated hash
      #
      def decorate_render(key, result)
        result.tap do
          value = send(key)

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
      def render_fields(type)
        fields = self.class.fields.fetch(type, [])

        fields.each_with_object({}) do |field, result|
          next unless field.enabled?(self)

          yield field, result
        end
      end

      # @param child [Halitosis] the child serializer
      # @param opts [Hash] the include options to assign to the child
      #
      # @return [nil, Hash] the rendered child
      #
      def render_child(child, opts)
        return unless child.class.included_modules.include?(Halitosis::Base)

        child.options[:include] ||= {}
        child.options[:include] = child.options[:include].merge(opts)

        child.options[:parent] = self

        child.render
      end
    end
  end
end
