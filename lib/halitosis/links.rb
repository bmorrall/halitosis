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
        fields.add(Links::Field.new(name, *, procedure))
      end

      # Declare a HAL +profile+ link for this resource.
      #
      # The link is only emitted when the serializer is rendered as the root
      # resource (i.e. not nested inside another serializer as a relationship).
      #
      # @param url [String] the profile URL
      #
      def profile(url)
        raise InvalidField, "#{name} profile requires a URL" unless url

        link :profile, value: url, if: ->(ctx) { ctx.root? }
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
        render_fields(Links::Field, context) do |field, result|
          value = field.value(context)

          result[field.name] = value if value
        end
      end
    end
  end
end

require "halitosis/links/field"
