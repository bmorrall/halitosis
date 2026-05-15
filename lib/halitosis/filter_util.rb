# frozen_string_literal: true

module Halitosis
  module FilterUtil
    module_function

    # Parse a filter param into an array of [key_string, value] pairs.
    #
    # Accepts a Hash (or any object responding to +each_pair+). Returns an
    # empty array for any other input type.
    #
    # @param param [Hash, nil] the filter param, typically from request params
    # @return [Array<Array(String, Object)>] pairs of [key, value]
    #
    def parse_filter_param(param)
      return [] unless param.respond_to?(:each_pair)

      pairs = []
      param.each_pair { |key, value| pairs << [key.to_s, value] }
      pairs
    end
  end
end
