# frozen_string_literal: true

module Halitosis
  module RootLinks
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @return [Halitosis::RootLinks::Field]
      #
      def root_link(name, **options, &procedure)
        fields.add(RootLinks::Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      # @param result [Hash] the fully-enveloped render output
      # @return [Hash]
      #
      def render_root(context, result)
        super.tap do |root|
          value = root_links(context)
          root[:_links] = root.fetch(:_links, {}).merge(value) if value.any?
        end
      end

      # @param context [Halitosis::Context] the render context
      # @return [Hash] root_links from fields
      #
      def root_links(context)
        render_fields(RootLinks::Field, context) do |field, result|
          value = field.value(context)

          result[field.name] = value if value || field.always_emit?
        end
      end
    end
  end
end

require "halitosis/root_links/field"
