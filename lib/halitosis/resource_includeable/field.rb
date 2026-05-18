# frozen_string_literal: true

module Halitosis
  module ResourceIncludeable
    class Field < Halitosis::Includeable::Field
      # Fetch the raw preload value for the top-level relationship (via its
      # +preload:+ option if set), then pass it to the +allow_include+ block.
      # The block may transform the value (e.g. eager-load associations) and
      # return the result, which is stored in the context so that
      # +Relationships::Field#value+ can pass it to the relationship block during
      # rendering.
      #
      # When no +preload:+ option is set on the relationship, the block receives
      # +nil+. If the block also returns +nil+, nothing is stored and the
      # relationship renders via its own block without a preloaded value.
      #
      # Returns +nil+ when no procedure is attached (declaration-only field).
      #
      # @param instance [Halitosis::Base] the serializer instance
      # @param context [Halitosis::Context] the render context
      #
      # @return [nil]
      #
      def apply(instance, context)
        return unless procedure

        rel_name = path.first
        rel_field = instance.class.fields
          .for_type(Relationships::Field)
          .find { |f| f.name == rel_name }

        # Seed the context with the raw value from the relationship's preload: guard,
        # but only once (multiple allow_include fields can share the same rel_name).
        preloads = context.fetch_local(:resource_includeable_preloads) || {}

        unless preloads.key?(rel_name)
          if (guard = rel_field&.preload_guard)
            preloads = preloads.merge(rel_name => context.call_instance(guard))
            context.store_local(:resource_includeable_preloads, preloads)
          end
        end

        # Pass the current preload value (nil if not seeded) to the allow_include block.
        result = context.call_instance_with(preloads[rel_name], procedure)

        if result
          existing = context.fetch_local(:resource_includeable_preloads) || {}
          context.store_local(:resource_includeable_preloads, existing.merge(rel_name => result))
        end

        nil
      end
    end
  end
end
