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
        fields.add(Field.new(name, options, procedure))
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with meta, if any
      #
      def render(**)
        super.tap do |result|
          next unless options.fetch(:include_root) { true }

          value = root_meta
          result[:_meta] = result.fetch(:_meta, {}).merge(value) if value.any?
        end
      end

      # @return [Hash] meta from fields
      #
      def root_meta(context = build_context)
        render_fields(Field, context) do |field, result|
          value = field.value(context)

          result[field.name] = value
        end
      end
    end
  end
end

require "halitosis/root_meta/field"
