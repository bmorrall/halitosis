# frozen_string_literal: true

module Halitosis
  module RootPermissions
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @return [Halitosis::RootPermissions::Field]
      #
      def root_permission(name, **options, &procedure)
        fields.add(RootPermissions::Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @param context [Halitosis::Context] the render context
      # @param result [Hash] the fully-enveloped render output
      # @return [Hash]
      #
      def render_root(context, result)
        super.tap do |root|
          value = root_permissions(context)
          root[:_permissions] = root.fetch(:_permissions, {}).merge(value) if value.any?
        end
      end

      # @param context [Halitosis::Context] the render context
      # @return [Hash] permissions from fields
      #
      def root_permissions(context)
        render_fields(RootPermissions::Field, context) do |field, result|
          value = field.value(context)
          result[field.name] = value || false
        end
      end
    end
  end
end

require "halitosis/root_permissions/field"
