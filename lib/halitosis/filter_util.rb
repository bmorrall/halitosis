# frozen_string_literal: true

module Halitosis
  module FilterUtil
    module_function

    # Parse a filter param into an array of [key_string, value] pairs.
    #
    # Accepts a Hash (or any object responding to +each_pair+). Nested hashes
    # are flattened into dot-notation keys, e.g. <tt>{ user: { name: "Alice" } }</tt>
    # becomes <tt>[["user.name", "Alice"]]</tt>. This means both
    # <tt>filter[user][name]=Alice</tt> and <tt>filter[user.name]=Alice</tt>
    # produce identical output and are handled by the same +filterable_by+ declaration.
    #
    # When +compound_names+ is provided, any key present in that collection stops
    # further descent — its hash value is yielded as-is rather than flattened.
    # This supports compound filter fields declared with the +keys:+ option.
    #
    # Returns an empty array for any non-hash input.
    #
    # @param param [Hash, nil] the filter param, typically from request params
    # @param prefix [String, nil] dot-notation prefix accumulated during recursion
    # @param compound_names [Array<String>] filter names that should not be flattened
    # @return [Array<Array(String, Object)>] pairs of [key, value]
    #
    def parse_filter_param(param, prefix = nil, compound_names: [])
      return [] unless param.respond_to?(:each_pair)

      pairs = []
      param.each_pair do |key, value|
        full_key = prefix ? "#{prefix}.#{key}" : key.to_s
        if value.respond_to?(:each_pair) && !compound_names.include?(full_key)
          pairs.concat(parse_filter_param(value, full_key, compound_names: compound_names))
        else
          pairs << [full_key, value]
        end
      end
      pairs
    end
  end
end
