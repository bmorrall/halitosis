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
      private

      # Evaluate +value_source+ via the serializer instance and cache the
      # result under +field_name+ in the context's local preloads hash.
      #
      # @param context [Halitosis::Context] the render context
      # @param field_name [Symbol, String] key to store under
      # @param value_source [String, Symbol, Proc] evaluated via +context.call_instance+
      #
      def store_preload(context, field_name, value_source)
        value = context.call_instance(value_source)
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
