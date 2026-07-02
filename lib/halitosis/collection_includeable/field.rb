# frozen_string_literal: true

module Halitosis
  module CollectionIncludeable
    # Pure path-declaration marker for a collection include path.
    #
    # Records which include paths are permitted; preload execution is handled
    # by +CollectionPreloader::Field+.
    #
    class Field < Halitosis::Field
      attr_reader :path

      # @param path [Array<Symbol>] ordered list of relationship segments,
      #   e.g. +[:author, :avatar]+
      # @param options [Hash] field options
      # @param procedure [nil] unused; preload logic lives in
      #   +CollectionPreloader::Field+
      #
      def initialize(path, options, procedure)
        @path = path.map(&:to_sym)
        super(path.join("."), options, procedure)
      end
    end
  end
end
