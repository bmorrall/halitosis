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
      def render
        if options.fetch(:include_links, true)
          decorate_render :links, super
        else
          super
        end
      end

      # @return [Hash] links from fields
      #
      def links
        render_fields(Field) do |field, result|
          value = field.value(self)

          result[field.name] = value if value
        end
      end
    end
  end
end

require "halitosis/links/field"
