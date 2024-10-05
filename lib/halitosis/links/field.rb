# frozen_string_literal: true

module Halitosis
  module Links
    class Field < Halitosis::Field
      # Links have special keywords that other fields don't, so override
      # the standard initializer to build options from keywords
      #
      def initialize(name, *args, procedure)
        super(name, self.class.build_options(args), procedure)
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

      # @return [nil, Hash]
      #
      def value(_context)
        hrefs = super

        attrs = options.fetch(:attrs, {})

        case hrefs
        when Array
          hrefs.map { |href| attrs.merge(href:) }
        when nil
          # no-op
        else
          attrs.merge(href: hrefs)
        end
      end

      class << self
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
