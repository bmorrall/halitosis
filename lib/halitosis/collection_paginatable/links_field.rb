# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Holds the URL-building procedure declared via +paginate_links+.
    #
    # Its presence in the fields registry is the sentinel that determines
    # whether pagination links should be emitted at render time. A serializer
    # that declares +paginate_with_pagy+ (or another pagination method) but
    # omits +paginate_links+ will have a +CollectionPaginatable::Field+ but no +LinksField+,
    # and no +_links+ output will be produced.
    #
    # Contrast with +CollectionPaginatable::Field+, which holds the pagination
    # procedure and adapter — this field answers
    # "how do I build a URL for a given page number?".
    #
    class LinksField < Halitosis::Field
      # Keys emitted by default when no +only:+ option is given.
      DEFAULT_KEYS = %i[self first last prev next].freeze

      def initialize(name, options, procedure)
        super
      end

      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        super

        return true if procedure

        raise InvalidField, "Pagination links #{name} must be defined with a proc"
      end

      # Apply the links procedure for a given page number.
      #
      # @param context [Halitosis::Context] the render context
      # @param page_number [Integer, nil] the target page number
      # @param query_params [Hash]
      # @return [String, nil]
      #
      def apply(context, page_number, query_params)
        context.call_instance(page_number, query_params, procedure)
      end

      # Filter page_numbers hash to the requested keys.
      #
      # When no +only:+ option was given all default keys are returned.
      # Pass +only:+ to emit a specific subset.
      #
      # @param page_numbers [Hash]
      # @return [Hash]
      #
      def filter_page_numbers(page_numbers)
        page_numbers.slice(*Array(options[:only]).map(&:to_sym))
      end
    end
  end
end
