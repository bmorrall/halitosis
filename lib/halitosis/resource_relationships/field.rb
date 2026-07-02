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

        return true if procedure

        raise InvalidField, "Relationship #{name} must be defined with a proc"
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
          context.call_instance(preloaded, procedure)
        else
          context.call_instance(procedure)
        end
      end
    end
  end
end
