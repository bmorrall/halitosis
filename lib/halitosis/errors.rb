# frozen_string_literal: true

module Halitosis
  class Error < StandardError; end

  ### Configuration Errors ###

  class InvalidCollection < StandardError; end

  class InvalidField < StandardError; end

  class InvalidResource < StandardError; end

  ### Rendering Errors ###

  class InvalidQueryParameter < Error
    def initialize(message, parameter)
      @parameter = parameter
      super(message)
    end

    attr_reader :parameter
  end

  class InvalidSortParameter < InvalidQueryParameter
    def initialize(message)
      super(message, "sort")
    end
  end

  class InvalidFilterParameter < InvalidQueryParameter
    def initialize(message, field_name = nil)
      super(message, field_name ? to_bracket_param(field_name.to_s) : "filter")
    end

    private

    def to_bracket_param(field_name)
      parts = field_name.split(".")
      "filter[#{parts.join("][")}]"
    end
  end

  # Accumulates validation error messages inside a +filterable_by+ block.
  # An instance is yielded as the third argument when the block accepts 3 args.
  # Initialized with the dot-notation field name; the namespace prefix (all but
  # the last segment) is preserved when a field name override is supplied to +add+.
  #
  # @example Simple message — uses the initialized field name
  #   filterable_by :status do |collection, value, errors|
  #     errors.add("must be one of: draft, published, archived") unless valid_status?(value)
  #     errors.none? ? collection.where(status: value) : nil
  #   end
  #
  # @example Field name override — leaf is replaced, namespace prefix is kept
  #   filterable_by :account do
  #     filterable_by :date_range do |collection, value, errors|
  #       errors.add("started_at", "is not a valid date") unless valid_date?(value)
  #       errors.none? ? collection : nil
  #     end
  #   end
  #   # errors.add("started_at", ...) reports under "account.started_at"
  #
  class FilterErrors
    attr_reader :field_name

    def initialize(field_name, prefix: nil)
      @field_name = field_name.to_s
      parts = @field_name.split(".")
      @namespace_prefix = prefix || ((parts.length > 1) ? parts[0..-2].join(".") : nil)
      @entries = []
    end

    # Add an error message.
    #
    # With one argument, the error is recorded under the initialized field name.
    # With two arguments, the first overrides the leaf field name — the namespace
    # prefix from the initialized name is prepended automatically.
    #
    # @overload add(message)
    #   @param message [String]
    # @overload add(field_name, message)
    #   @param field_name [String, Symbol] leaf name to report the error under
    #   @param message [String]
    #
    def add(field_name_or_message, message = nil)
      if message.nil?
        @entries << [@field_name, field_name_or_message]
      else
        leaf = field_name_or_message.to_s
        resolved = @namespace_prefix ? "#{@namespace_prefix}.#{leaf}" : leaf
        @entries << [resolved, message]
      end
    end

    def any?
      @entries.any?
    end

    def none?
      @entries.none?
    end

    # Returns the first [field_name, messages_array] pair.
    def first
      to_h.first
    end

    # Returns a hash of { field_name => [messages] }, grouped by field name.
    def to_h
      @entries.each_with_object({}) do |(name, msg), hash|
        (hash[name] ||= []) << msg
      end
    end
  end

  class InvalidPaginationParameter < InvalidQueryParameter
    def initialize(message)
      super(message, "page")
    end
  end

  class InvalidIncludeParameter < InvalidQueryParameter
    def initialize(message)
      super(message, "include")
    end
  end
end
