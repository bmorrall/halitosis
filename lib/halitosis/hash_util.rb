# frozen_string_literal: true

module Halitosis
  module HashUtil
    module_function

    # Transform include params into a hash
    #
    # @param object [Hash, Array, String]
    #
    # @return [Hash]
    def hasherize_include_option(object)
      case object
      when Hash
        object.transform_keys(&:to_s)
      when String, Symbol
        object.to_s.split(",").inject({}) do |output, key|
          f, value = key.split(".", 2)
          deep_merge(output, f => value ? hasherize_include_option(value) : {})
        end
      when Array
        object.inject({}) do |output, value|
          deep_merge(output, hasherize_include_option(value))
        end
      else
        object
      end
    end

    # Deep merge two hashes
    #
    # @param hash [Hash]
    # @param other_hash [Hash]
    #
    # @return [Hash]
    def deep_merge(hash, other_hash)
      hash.merge(other_hash) do |key, this_val, other_val|
        if this_val.is_a?(Hash) && other_val.is_a?(Hash)
          deep_merge(this_val, other_val)
        else
          other_val
        end
      end
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
