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
      def render
        if options.fetch(:include_meta, true)
          decorate_render :meta, super
        else
          super
        end
      end

      # @return [Hash] meta from fields
      #
      def meta
        render_fields(Field.name) do |field, result|
          value = field.value(self)

          result[field.name] = value
        end
      end
    end
  end
end

require "halitosis/meta/field"
