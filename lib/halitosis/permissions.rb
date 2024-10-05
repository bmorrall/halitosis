# frozen_string_literal: true

module Halitosis
  module Permissions
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @return [Halitosis::Permissions::Field]
      #
      def permission(name, **options, &procedure)
        fields.add(Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with permissions, if any
      #
      def render_with_context(context)
        if context.fetch(:include_permissions, true)
          decorate_render :permissions, context, super
        else
          super
        end
      end

      # @return [Hash] permissions from fields
      #
      def permissions(context = build_context)
        render_fields(Field, context) do |field, result|
          value = field.value(context)

          result[field.name] = value || false
        end
      end
    end
  end
end

require "halitosis/permissions/field"
