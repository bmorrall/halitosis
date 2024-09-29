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
      def render
        if options.fetch(:include_permissions, true)
          decorate_render :permissions, super
        else
          super
        end
      end

      # @return [Hash] permissions from fields
      #
      def permissions
        render_fields(Field.name) do |field, result|
          value = field.value(self)

          result[field.name] = value if value
        end
      end
    end
  end
end

require "halitosis/permissions/field"
