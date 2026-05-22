# frozen_string_literal: true

module Halitosis
  # Shared base for JSON:API error entry serializers.
  # Only +attribute+, +link+, and +meta+ fields may be defined on a subclass.
  class ErrorEntry
    include Halitosis::Base
    include Halitosis::Attributes
    include Halitosis::Links
    include Halitosis::Meta

    # Class-level DSL shortcuts for JSON:API error fields.
    # Thin wrappers over the standard Halitosis +attribute+ DSL.
    module ClassMethods
      def id(&blk) = attribute(:id, &blk)
      def code(&blk) = attribute(:code, &blk)
      def title(&blk) = attribute(:title, &blk)
      def status(&blk) = attribute(:status, &blk)
      def detail(&blk) = attribute(:detail, &blk)

      def source_pointer(&blk)
        define_method(:_source_value, &blk)
        private :_source_value
        attribute(:source) { {pointer: _source_value} }
      end

      def source_parameter(&blk)
        define_method(:_source_value, &blk)
        private :_source_value
        attribute(:source) { {parameter: _source_value} }
      end

      def source_header(&blk)
        define_method(:_source_value, &blk)
        private :_source_value
        attribute(:source) { {header: _source_value} }
      end
    end

    extend ClassMethods

    required_option :error
  end
end
