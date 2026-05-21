# frozen_string_literal: true

module Halitosis
  # Serializes a single ActiveModel::Error to a JSON:API error object.
  #
  # Subclass this to add extra JSON:API error fields using the DSL shortcuts:
  #
  # @example
  #   class MyErrorSerializer < Halitosis::ErrorSerializer
  #     title  { error.type.to_s.humanize }
  #     status { "422" }
  #   end
  #
  #   render json: Halitosis::ErrorsSerializer.new(
  #     record.errors,
  #     param: "article",
  #     error_serializer_class: MyErrorSerializer
  #   ), status: :unprocessable_entity
  class ErrorSerializer
    include Halitosis

    # Class-level DSL shortcuts for JSON:API error fields.
    # Thin wrappers over the standard Halitosis +attribute+ DSL.
    # Shared with +ExceptionSerializer::ErrorEntry+.
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
    required_option :param

    attribute(:code, unless: -> { !error.type.is_a?(Symbol) }) { error_code }
    attribute(:detail) { error.full_message }
    attribute(:source, unless: -> { error.attribute.nil? || error.attribute == :base }) do
      {pointer: "/#{param}/#{error.attribute}"}
    end

    private

    def error_code
      (error.attribute == :base) ? error.type.to_s : "#{error.attribute}_#{error.type}"
    end
  end
end
