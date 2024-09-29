# frozen_string_literal: true

module Halitosis
  module Relationships
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::Relationships::Field]
      #
      def relationship(name, options = {}, &procedure)
        fields.add(Field.new(name, options, procedure))
      end

      alias_method :rel, :relationship
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with relationships resources, if any
      #
      def render
        decorate_render :relationships, super
      end

      # @return [Hash] hash of rendered resources to include
      #
      def relationships
        render_fields(Field.name) do |field, result|
          value = instance_eval(&field.procedure)

          child = relationships_child(field.name.to_s, value)

          result[field.name] = child if child
        end
      end

      # @return [nil, Hash, Array<Hash>] either a single rendered child
      #   serializer or an array of them
      #
      def relationships_child(key, value)
        return unless value

        opts = child_relationship_opts(key)

        if value.is_a?(Array)
          value.map { |item| render_child(item, opts) }.compact
        else
          render_child(value, opts)
        end
      end

      # @param key [String]
      #
      # @return [Hash]
      #
      def child_relationship_opts(key)
        opts = include_options.fetch(key, {})

        # Turn { :report => 1 } into { :report => {} } for child
        opts = {} unless opts.is_a?(Hash)

        opts
      end

      # @return [Hash] hash of options with top level string keys
      #
      def include_options
        @include_options ||= Halitosis::HashUtil.stringify_params(options.fetch(:include, {}))
      end
    end
  end
end

require "halitosis/relationships/field"
