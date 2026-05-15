# frozen_string_literal: true

module Halitosis
  module RootPermissions
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @return [Halitosis::RootPermission::Field]
      #
      def root_permission(name, **options, &procedure)
        fields.add(RootPermissions::Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with permissions, if any
      #
      def render(**)
        super.tap do |result|
          value = root_permissions
          result[:_permissions] = result.fetch(:_permissions, {}).merge(value) if value.any?
        end
      end

      # @return [Hash] permissions from fields
      #
      def root_permissions(context = build_context)
        render_fields(RootPermissions::Field, context) do |field, result|
          next unless options.fetch(:include_root) { true }

          value = field.value(context)
          result[field.name] = value || false
        end
      end
    end
  end
end

require "halitosis/root_permissions/field"
