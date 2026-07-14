# frozen_string_literal: true

module Halitosis
  module Relationships
    class Field < Halitosis::Field
      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        super

        return true if procedure

        raise InvalidField, "Relationship #{name} must be defined with a proc"
      end

      # @param context [Halitosis::Context] the serializer context
      # @return [Object] when a preload value has been stored in context by
      #   +ResourceIncludeable+, it is passed as the first argument to the block so
      #   the block can receive and use it (e.g. +|preloaded = nil|+). When no
      #   preload is stored, the block is called with +nil+ as the first argument.
      #   For non-Proc procedures (Symbol/String), existing dispatch is unchanged.
      #
      def value(context)
        options.fetch(:value) do
          preloads = context.fetch_local(:resource_includeable_preloads) || {}
          preloaded = preloads[name]

          if procedure.is_a?(Proc)
            context.call_instance_with(preloaded, procedure)
          else
            call_procedure(context)
          end
        end
      end

      # Returns the guard used to fetch the raw preload value for this relationship.
      # Set via the +preload:+ option when calling +relationship+.
      #
      # @return [Symbol, String, Proc, nil]
      #
      def preload_guard
        options[:preload]
      end

      # Check whether this definition should be included for the given instance
      #
      # @param instance [Object]
      #
      # @return [true, false]
      #
      def enabled?(context)
        return false unless super

        opts = context.include_options

        # Field name must appear in instance included option keys
        return false unless opts.include?(name.to_s)

        # Check value of included option for definition name
        !%w[0 false].include?(opts.fetch(name.to_s).to_s)
      end
    end
  end
end
