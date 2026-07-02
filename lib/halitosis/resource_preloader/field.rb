# frozen_string_literal: true

module Halitosis
  module ResourcePreloader
    # Stores a preload registration for a single relationship: the source
    # method to call (+key+) and the cache key under which the result is stored
    # (+name+).
    #
    # Extends +Halitosis::Field+ for registry uniqueness tracking and
    # +if:+/+unless:+ condition support on the preload itself.
    #
    class Field < Halitosis::Field
      attr_reader :key

      # @param name [Symbol, String] the cache key and relationship name,
      #   e.g. +:violations+
      # @param options [Hash] field options; +:key+ is extracted and stored
      #   separately as the source method name
      # @param _procedure [nil] unused; preload fields have no rendered procedure
      #
      def initialize(name, options, _procedure = nil)
        opts = Halitosis::HashUtil.symbolize_hash(options)
        @key = opts.delete(:key)
        super(name, opts, nil)
      end

      # @return [true]
      #
      def validate
        true
      end
    end
  end
end
