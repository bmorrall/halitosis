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
      def render_with_context(context)
        decorate_render :relationships, context, super
      end

      # @return [Hash] hash of rendered resources to include
      #
      def relationships(context = build_context)
        # Do not validation non-root collections (as they pass values directly to children)
        validate_relationships!(context) unless collection?

        render_fields(Field, context) do |field, result|
          value = field.value(context)

          child = relationships_child(field.name.to_s, context, value)

          result[field.name] = child if child
        end
      end

      # @return [nil, Hash, Array<Hash>] either a single rendered child
      #   serializer or an array of them
      #
      def relationships_child(key, context, value)
        return unless value

        opts = child_relationship_opts(key, context)

        if value.is_a?(Array)
          value.map { |item| render_child(item, context, opts) }.compact
        else
          render_child(value, context, opts)
        end
      end

      # @param key [String]
      #
      # @return [Hash]
      #
      def child_relationship_opts(key, context)
        opts = context.include_options.fetch(key, {})

        # Turn { :report => 1 } into { :report => {} } for child
        opts = {} unless opts.is_a?(Hash)

        opts
      end

      private

      def validate_relationships!(context)
        opts = context.include_options.keys.map(&:to_s)

        opts -= self.class.fields.for_type(Field).map { |field| field.name.to_s }

        return if opts.none?

        resource_label = [self.class.resource_type, "resource"].compact.join(" ")
        raise Halitosis::InvalidQueryParameter.new("The #{resource_label} does not have a `#{opts.first}` relationship path.", "include")
      end
    end
  end
end

require "halitosis/relationships/field"
