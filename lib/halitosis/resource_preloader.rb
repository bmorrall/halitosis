# frozen_string_literal: true

module Halitosis
  # Owns the +preload+ DSL for resource serializers and provides
  # +preload_value+ for executing registered preloads into the context cache.
  #
  # Included by +ResourceRelationships+ (for the preload DSL and preload
  # execution) and transitively by +ResourceIncludes+ (via +ResourcePreloader+
  # being included in its +self.included+ hook). Ruby's idempotent module
  # inclusion means including it from both is safe.
  #
  module ResourcePreloader
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # Register a preload for the named relationship.
      #
      # @param source_key [Symbol, String] the source method to call via
      #   +default_procedure_for+, e.g. +:flight_violations+
      # @param as [Symbol, String] the relationship name and cache key,
      #   e.g. +:violations+. Defaults to +source_key+.
      # @param options [Hash] optional +if:+/+unless:+ conditions on the
      #   preload itself
      #
      # @return [nil]
      #
      def preload(source_key, as: source_key, **options)
        name = as.to_sym
        key = source_key.to_sym

        return if fields.find_by_name(ResourcePreloader::Field, name)

        fields.add(ResourcePreloader::Field.new(name, options.merge(key: key), nil))

        nil
      end

      # Returns true if a preload has been registered under +name+.
      #
      # @param name [Symbol, String]
      # @return [Boolean]
      #
      def preload_registered?(name)
        !!fields.find_by_name(ResourcePreloader::Field, name.to_sym)
      end
    end

    module InstanceMethods
      private

      # Look up the preloader field for +name+ and, if registered, execute the
      # preload and store the result in the context cache. Deduplicates
      # source-key evaluation across multiple relationships that share the same
      # source method, using the context's local storage as the deduplication map.
      #
      # @param context [Halitosis::Context]
      # @param name [Symbol]
      #
      def preload_value(context, name)
        preloader_field = self.class.fields.find_by_name(ResourcePreloader::Field, name)
        return unless preloader_field

        computed = context.fetch_local(:preload_computed) || {}

        unless computed.key?(preloader_field.key)
          computed[preloader_field.key] = context.call_instance(
            self.class.default_procedure_for(preloader_field.key)
          )
          context.store_local(:preload_computed, computed)
        end

        store_preload(context, preloader_field.name, computed[preloader_field.key])
      end
    end
  end
end

require "halitosis/resource_preloader/field"
