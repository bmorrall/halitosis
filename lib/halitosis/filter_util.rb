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
    # Returns an empty array for any non-hash input.
    #
    # @param param [Hash, nil] the filter param, typically from request params
    # @param prefix [String, nil] dot-notation prefix accumulated during recursion
    # @return [Array<Array(String, Object)>] pairs of [key, value]
    #
    def parse_filter_param(param, prefix = nil)
      return [] unless param.respond_to?(:each_pair)

      pairs = []
      param.each_pair do |key, value|
        full_key = prefix ? "#{prefix}.#{key}" : key.to_s
        if value.respond_to?(:each_pair)
          pairs.concat(parse_filter_param(value, full_key))
        else
          pairs << [full_key, value]
        end
      end
      pairs
    end
  end
end
