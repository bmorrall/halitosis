# frozen_string_literal: true

module Halitosis
  module HashUtil
    module_function

    # Transform hash keys into strings if necessary
    #
    # @param hash [Hash, Array, String]
    #
    # @return [Hash]
    #
    def stringify_params(hash)
      case hash
      when Hash
        hash.transform_keys(&:to_s)
      when String
        hash.split(",").inject({}) do |output, key|
          f, value = key.split(".", 2)
          output.merge(f => value ? stringify_params(value) : true)
        end
      when Array
        hash.map { |item| stringify_params(item) }.inject({}, &:merge)
      when nil
        {}
      else
        hash
      end
    end

    # Transform hash keys into strings if necessary
    #
    # @param hash [Hash, Array, String]
    #
    # @return [Hash]
    #
    def stringify_hash(hash)
      hash.transform_keys(&:to_s)
    end

    # Transform hash keys into symbols if necessary
    #
    # @param hash [Hash]
    #
    # @return [Hash]
    #
    def symbolize_hash(hash)
      if hash.respond_to?(:transform_keys)
        hash.transform_keys(&:to_sym).transform_values(&method(:symbolize_hash))
      else
        hash
      end
    end
  end
end
