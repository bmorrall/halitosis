# frozen_string_literal: true

module Halitosis
  module ResourceRelationships
    class Field < Halitosis::Field
      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        super

        if options.key?(:preload) && options[:preload] != false &&
            !options[:preload].is_a?(Symbol) && !options[:preload].is_a?(String)
          raise InvalidField, "Relationship #{name} preload option must be a Symbol, String, or false"
        end

        return true if procedure

        raise InvalidField, "Relationship #{name} must be defined with a proc"
      end

      # The key used to look up a stored preload value for this field.
      # Defaults to the field name, but can be overridden with the +preload:+ option.
      #
      # @return [Symbol]
      #
      def preload_key
        (options.fetch(:preload, name) || name).to_sym
      end

      # Check whether this definition should be included for the given instance
      #
      # @param instance [Object]
      #
      # @return [true, false] whether an explicit +preload:+ option was given with a usable key
      #
      def preload?
        !!options[:preload]
      end

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

      # When the procedure accepts one or more arguments, pass the preloaded
      # value for this field as the first argument. This allows relationship
      # blocks to receive a cached value via the preload mechanism:
      #
      #   relationship(:articles) { |articles| articles.map { ArticleSerializer.new(_1) } }
      #
      # When the procedure has arity 0, it is called as normal.
      #
      # @param context [Halitosis::Context]
      # @param preloaded [Object, nil] value previously stored via +store_preload+
      #
      def value(context, preloaded = nil)
        call_procedure(context, preloaded)
      end

      private

      def call_procedure(context, preloaded = nil)
        if procedure.arity != 0
          context.call_instance_with(preloaded, procedure)
        else
          context.call_instance(procedure)
        end
      end
    end
  end
end
