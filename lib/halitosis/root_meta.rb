# frozen_string_literal: true

module Halitosis
  module RootMeta
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @return [Halitosis::RootMeta::Field]
      #
      def root_meta(name, **options, &procedure)
        fields.add(RootMeta::Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      # @param result [Hash] the fully-enveloped render output
      # @return [Hash]
      #
      def render_root(context, result)
        super.tap do |root|
          value = root_meta(context)
          root[:_meta] = root.fetch(:_meta, {}).merge(value) if value.any?
        end
      end

      # @param context [Halitosis::Context] the render context
      # @return [Hash] meta from fields
      #
      def root_meta(context)
        render_fields(RootMeta::Field, context) do |field, result|
          value = field.value(context)

          result[field.name] = value
        end
      end
    end
  end
end

require "halitosis/root_meta/field"
