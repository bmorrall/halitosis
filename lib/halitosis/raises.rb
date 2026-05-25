# frozen_string_literal: true

module Halitosis
  module Raises
    private

    # Raise an +InvalidFilterParameter+ error for a declared filter field.
    #
    # @param field_name [String, Symbol]
    # @param error_message [String, nil] optional detail appended after a colon
    # @raise [Halitosis::InvalidFilterParameter]
    #
    def raise_invalid_filter_parameter(field_name, error_message = nil)
      safe_field = sanitize_parameter(field_name)
      base = "The #{resource_label} can not be filtered by '#{safe_field}'"
      message = error_message ? "#{base}: #{error_message}" : base

      raise Halitosis::InvalidFilterParameter.new(message, safe_field)
    end

    # Raise an +InvalidIncludeParameter+ error for an unknown relationship path.
    #
    # @param relationship_path [String, Symbol]
    # @raise [Halitosis::InvalidIncludeParameter]
    #
    def raise_invalid_include_parameter(relationship_path)
      safe_path = sanitize_parameter(relationship_path, /[^\w.]/)

      raise Halitosis::InvalidIncludeParameter.new(
        "The #{resource_label} does not have a `#{safe_path}` relationship path."
      )
    end

    # Raise an +InvalidPaginationParameter+ error.
    #
    # When +param+ is supplied the message names the specific parameter;
    # when omitted the message refers to the provided values in general.
    #
    # @param param [String, Symbol, nil] the parameter name, e.g. +page[size]+
    # @param error_message [String, nil] optional detail appended after a colon
    # @raise [Halitosis::InvalidPaginationParameter]
    #
    def raise_invalid_pagination_parameter(param = nil, error_message = nil)
      safe_param = sanitize_parameter(param, /[^\w.\[\]]/)
      base = safe_param ? "The #{resource_label} can not be paginated with the provided '#{safe_param}' value" :
                          "The #{resource_label} can not be paginated with the provided values"
      message = error_message ? "#{base}: #{error_message}" : base

      raise Halitosis::InvalidPaginationParameter.new(message)
    end

    # Raise an +InvalidSortParameter+ error for a sort token.
    #
    # @param sort_token [String] the sort token, e.g. "name" or "-name"
    # @param error_message [String, nil] optional detail appended after a colon
    # @raise [Halitosis::InvalidSortParameter]
    #
    def raise_invalid_sort_parameter(sort_token, error_message = nil)
      safe_token = sanitize_parameter(sort_token, /[^\w.-]/)
      base = "The #{resource_label} can not be sorted by '#{safe_token}'"
      message = error_message ? "#{base}: #{error_message}" : base

      raise Halitosis::InvalidSortParameter.new(message)
    end

    # Build a human-readable label for the serializer's resource type,
    # appending "collection" or "resource" based on +collection?+.
    #
    # @return [String]
    #
    def resource_label
      kind = self.class.collection? ? "collection" : "resource"
      [self.class.resource_type, kind].compact.join(" ")
    end

    # Strip characters outside the allowed set and truncate to 50 characters.
    # Returns +nil+ when +value+ is +nil+.
    #
    # @param value [String, Symbol, nil]
    # @param pattern [Regexp] characters to remove (default: anything not a word char or dot)
    # @return [String, nil]
    #
    def sanitize_parameter(value, pattern = /[^\w.]/)
      value&.to_s&.gsub(pattern, "")&.slice(0, 50)
    end
  end
end
