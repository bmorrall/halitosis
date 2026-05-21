# frozen_string_literal: true

module Halitosis
  # Utility for parsing JSON:API sparse fieldset parameters.
  #
  module FieldsUtil
    module_function

    # Parse a raw field list for a single resource type into a Set of field
    # name strings. Accepts a comma-separated String, a Symbol, an Array of
    # either, or nil.
    #
    # Returns +nil+ when the input is blank or of an unsupported type, meaning
    # "no restriction" rather than "no fields allowed".
    #
    # @param value [String, Symbol, Array, nil]
    # @return [Set<String>, nil]
    #
    def parse_field_names(value)
      names = case value
      when nil, String, Symbol
        (value || "").to_s.split(",").filter_map do |token|
          stripped = token.strip
          stripped unless stripped.empty?
        end
      when Array
        value.flat_map { |v| parse_field_names(v)&.to_a || [] }
      else
        return nil
      end

      Set.new(names)
    end

    # Parse a full JSON:API +fields+ param into a registry hash mapping
    # resource type strings to Sets of permitted field name strings.
    # Entries with blank field lists are omitted. Returns +nil+ when the
    # param is not a hash or yields no entries.
    #
    # @param param [Hash, nil]
    # @return [Hash{String => Set<String>}, nil]
    #
    def build_registry(param)
      return nil unless param.respond_to?(:each_pair)

      registry = {}

      param.each_pair do |type, raw|
        set = parse_field_names(raw)
        registry[type.to_s] = set unless set.nil?
      end

      registry.empty? ? nil : registry
    end
  end
end
