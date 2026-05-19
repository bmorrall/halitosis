# frozen_string_literal: true

module Halitosis
  # Provides per-field value caching into the render context's local storage.
  #
  # Values are stored under the +:includeable_preloads+ key in context local
  # storage as a +Symbol => value+ hash. Each entry is keyed by +field_name+
  # and is scoped to the context instance — never shared with child contexts.
  #
  module Preloadable
    def self.included(base)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      # @param context [Halitosis::Context]
      #
      def before_render(context)
        super

        preload_context(context)
      end

      # Hook called by +before_render+ to allow subclasses to populate preload
      # storage before field rendering begins. Override in a serializer class to
      # perform bulk preloading against the render context.
      #
      # @param _context [Halitosis::Context]
      #
      def preload_context(_context)
      end

      private

      # Store +value+ under +field_name+ in the context's local preloads hash.
      #
      # @param context [Halitosis::Context] the render context
      # @param field_name [Symbol, String] key to store under
      # @param value [Object] the value to cache
      #
      def store_preload(context, field_name, value)
        current = context.fetch_local(:includeable_preloads) || {}

        context.store_local(:includeable_preloads, current.merge(field_name.to_sym => value))
      end

      # Retrieve a previously stored preloaded value for +field_name+.
      #
      # @param context [Halitosis::Context] the render context
      # @param field_name [Symbol, String]
      # @return [Object, nil]
      #
      def fetch_preload(context, field_name)
        (context.fetch_local(:includeable_preloads) || {})[field_name.to_sym]
      end

      # Returns +true+ when a preloaded value has been stored for +field_name+,
      # even if the stored value is +nil+.
      #
      # @param context [Halitosis::Context] the render context
      # @param field_name [Symbol, String]
      # @return [Boolean]
      #
      def preloaded?(context, field_name)
        !!context.fetch_local(:includeable_preloads)&.key?(field_name.to_sym)
      end
    end
  end
end
