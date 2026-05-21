# frozen_string_literal: true

module Halitosis
  module Links
    class Field < Halitosis::Field
      # Links have special keywords that other fields don't, so override
      # the standard initializer to build options from keywords
      #
      def initialize(name, *args, procedure)
        options = self.class.build_options(args)

        if options.key?(:template)
          procedure = options.delete(:template)
          options[:attrs][:templated] = true
        end

        super(name, options, procedure)
      end

      # The key used to look up a stored preload value for this link, or +nil+
      # if this link was not created from a preloaded relationship.
      #
      # @return [Symbol, nil]
      #
      def preload_key
        options[:preload_key]
      end

      # Returns +true+ when a preload key is set, the field is enabled, and the
      # procedure accepts an argument (i.e. it will actually use the preloaded
      # value). 0-arity procs and static +value:+ links are excluded.
      #
      # @param context [Halitosis::Context]
      # @return [true, false]
      #
      def preload?(context)
        return false unless preload_key
        return false unless procedure&.arity&.nonzero?

        enabled?(context)
      end

      # Whether to emit this field in +_links+ even when its value is +nil+.
      #
      # Returns +false+ by default. Override in subclasses that must always
      # appear in the +_links+ hash (e.g. pagination link fields).
      #
      # @return [Boolean]
      #
      def always_emit?
        false
      end

      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the field is invalid
      #
      def validate
        super

        return true if procedure || options.key?(:value)

        raise InvalidField,
          "Link #{name} requires either procedure or explicit value"
      end

      # @param context [Halitosis::Context]
      # @param preloaded [Object, nil] value from the preload cache, if any
      #
      # @return [nil, Hash]
      #
      def value(context, preloaded = nil)
        hrefs = if options.key?(:value)
          options[:value]
        else
          call_procedure(context, preloaded)
        end

        attrs = options.fetch(:attrs, {}).transform_values do |v|
          v.is_a?(Proc) ? context.call_instance(v) : v
        end

        case hrefs
        when Array
          hrefs.map { |href| attrs.merge(href:) }
        when nil
          # no-op
        else
          attrs.merge(href: hrefs)
        end
      end

      private

      # @param context [Halitosis::Context]
      # @param preloaded [Object, nil]
      #
      def call_procedure(context, preloaded = nil)
        if preload_key && procedure&.arity&.nonzero?
          context.call_instance(preloaded, procedure)
        else
          context.call_instance(procedure || name)
        end
      end

      public

      class << self
        # HAL link object properties that may be passed as hash options.
        # Each key is extracted from the trailing options hash and merged
        # into +:attrs+ so it appears alongside +href+ in the rendered output.
        #
        PROPERTIES = %i[type deprecation name profile title hreflang].freeze

        # Build hash of options from flexible field arguments
        #
        # @param args [Array] the raw field arguments
        #
        # @return [Hash] standardized hash of options
        #
        def build_options(args)
          {}.tap do |options|
            options.merge!(args.pop) if args.last.is_a?(Hash)

            options[:attrs] ||= {}
            options[:attrs].merge!(build_attrs(args))

            PROPERTIES.each do |prop|
              options[:attrs][prop] = options.delete(prop) if options.key?(prop)
            end
          end
        end

        # @param keywords [Array] array of special keywords
        #
        # @raise [Halitosis::InvalidField] if a keyword is unrecognized
        #
        def build_attrs(keywords)
          keywords.each_with_object({}) do |keyword, attrs|
            case keyword
            when :templated, "templated"
              attrs[:templated] = true
            else
              raise InvalidField, "Unrecognized link keyword: #{keyword}"
            end
          end
        end
      end
    end
  end
end
