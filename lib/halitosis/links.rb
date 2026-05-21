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

      # Declare a HAL +self+ link for this resource.
      #
      # @example
      #   self_link { article_url(id) }
      #
      def self_link(&procedure)
        raise InvalidField, "#{name} self_link requires a block" unless procedure

        link :self, &procedure
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
      # Pre-populate the preload cache for any link fields that declare a
      # +preload_key+ and have not yet been populated (e.g. when the
      # corresponding relationship was not requested). Fires as part of the
      # +preload_context+ chain, after relationship preloads have run.
      #
      # @param context [Halitosis::Context]
      #
      def preload_context(context)
        preloads = {}

        self.class.fields.for_type(Links::Field).each do |field|
          next unless field.preload?(context)
          next if preloaded?(context, field.name)

          pk = field.preload_key

          unless preloads.key?(pk)
            preloads[pk] = context.call_instance(self.class.default_procedure_for(pk))
          end

          store_preload(context, field.name, preloads[pk])
        end

        super
      end

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
          pk = field.preload_key
          preloaded = fetch_preload(context, pk) if pk && preloaded?(context, pk)
          value = field.value(context, preloaded)

          result[field.name] = value if value || field.always_emit?
        end
      end
    end
  end
end

require "halitosis/links/field"
