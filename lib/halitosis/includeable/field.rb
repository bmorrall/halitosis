# frozen_string_literal: true

module Halitosis
  module Includeable
    # Base field class shared by +CollectionIncludeable+ and +ResourceIncludeable+.
    #
    # Stores a dot-joined path name alongside the raw path segments. Subclasses
    # implement +#apply+ to deliver the preload procedure to the appropriate subject
    # (collection or resource).
    #
    class Field < Halitosis::Field
      attr_reader :path

      # @param path [Array<Symbol>] ordered list of relationship segments, e.g. [:author, :avatar]
      # @param options [Hash] field options
      # @param procedure [Proc, nil] optional runtime block; +nil+ registers the path as allowed
      #   with no preload behaviour.
      #
      def initialize(path, options, procedure)
        @path = path.map(&:to_sym)
        super(path.join("."), options, procedure)
      end
    end
  end
end
