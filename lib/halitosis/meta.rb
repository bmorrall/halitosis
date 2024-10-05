# frozen_string_literal: true

module Halitosis
  module Meta
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @return [Halitosis::Meta::Field]
      #
      def meta(name, **options, &procedure)
        fields.add(Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with meta, if any
      #
      def render_with_context(context)
        if context.fetch(:include_meta, true)
          decorate_render :meta, context, super
        else
          super
        end
      end

      # @return [Hash] meta from fields
      #
      def meta(context = build_context)
        render_fields(Field, context) do |field, result|
          value = field.value(context)

          result[field.name] = value
        end
      end
    end
  end
end

require "halitosis/meta/field"
