# frozen_string_literal: true

module Halitosis
  # Utility for parsing the sort query parameter into an ordered list of
  # [field_name, ascending] directives.
  #
  # Mirrors the structure of HashUtil, which handles include param parsing.
  #
  module SortUtil
    module_function

    # Parse a sort param into an ordered array of [name, ascending] pairs.
    #
    # Accepts a comma-separated string, an array of strings, a symbol, or nil.
    # Array elements are themselves parsed recursively, so mixed arrays of
    # strings and comma-joined strings are supported.
    #
    # The direction prefix convention is:
    #   "name"  => ascending  (true)
    #   "-name" => descending (false)
    #
    # @param param [String, Symbol, Array, nil] the raw sort param value
    #
    # @return [Array<Array(String, Boolean)>] list of [field_name, ascending] pairs
    #
    # @example
    #   SortUtil.parse_sort_param("name")            # => [["name", true]]
    #   SortUtil.parse_sort_param("-name")           # => [["name", false]]
    #   SortUtil.parse_sort_param("name,-age")       # => [["name", true], ["age", false]]
    #   SortUtil.parse_sort_param(["name", "-age"])  # => [["name", true], ["age", false]]
    #
    def parse_sort_param(param)
      case param
      when Array
        param.flat_map { |element| parse_sort_param(element) }
      when String, Symbol
        param.to_s.split(",").filter_map do |token|
          stripped = token.strip
          parse_sort_token(stripped) unless stripped.empty?
        end
      else
        []
      end
    end

    # Parse a single sort token into a [name, ascending] pair.
    #
    # @param token [String] a single sort token, e.g. "name" or "-name"
    #
    # @return [Array(String, Boolean)] the field name and direction
    #
    def parse_sort_token(token)
      [token.delete_prefix("-"), !token.start_with?("-")]
    end
  end
end
