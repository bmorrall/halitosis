# frozen_string_literal: true

module Halitosis
  module Links
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @return [Halitosis::Links::Field]
      #
      def link(name, *, &procedure)
        fields.add(Field.new(name, *, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with links, if any
      #
      def render_with_context(context)
        if context.fetch(:include_links, true)
          decorate_render :links, context, super
        else
          super
        end
      end

      # @return [Hash] links from fields
      #
      def links(context = build_context)
        render_fields(Field, context) do |field, result|
          value = field.value(context)

          result[field.name] = value if value
        end
      end
    end
  end
end

require "halitosis/links/field"
