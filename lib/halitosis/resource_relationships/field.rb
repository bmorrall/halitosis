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

        if options.key?(:preload) && options[:preload] != false && options[:preload] != true &&
            !options[:preload].is_a?(Symbol) && !options[:preload].is_a?(String)
          raise InvalidField, "Relationship #{name} preload option must be a Symbol, String, true, or false"
        end

        if procedure&.arity&.nonzero? && !options.key?(:preload)
          raise InvalidField, "Relationship #{name} block accepts arguments but no `preload:` option is set"
        end

        return true if procedure

        raise InvalidField, "Relationship #{name} must be defined with a proc"
      end

      # The key used to look up a stored preload value for this field.
      # Defaults to the field name, but can be overridden with a Symbol or String
      # +preload:+ option. +true+ and +false+ both fall back to the field name.
      #
      # @return [Symbol]
      #
      def preload_key
        value = options[:preload]
        (value.is_a?(Symbol) || value.is_a?(String)) ? value.to_sym : name.to_sym
      end

      # Returns +true+ only when a usable +preload:+ option was given *and*
      # the field is enabled for the given context.
      #
      # @param context [Halitosis::Context]
      # @return [true, false]
      #
      def preload?(context)
        return false unless options[:preload]

        enabled?(context)
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
