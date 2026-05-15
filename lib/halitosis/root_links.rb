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
      # @return [Hash] the rendered hash with link, if any
      #
      def render(**)
        super.tap do |result|
          next unless options.fetch(:include_root) { true }

          value = root_links
          result[:_links] = result.fetch(:_links, {}).merge(value) if value.any?
        end
      end

      # @return [Hash] link from fields
      #
      # @return [Hash] root_links from fields
      #
      def root_links(context = build_context)
        render_fields(RootLinks::Field, context) do |field, result|
          value = field.value(context)

          result[field.name] = value if value
        end
      end
    end
  end
end

require "halitosis/root_links/field"
