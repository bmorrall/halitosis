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
  #
  # Only +attribute+, +link+, and +meta+ fields may be defined on an error serializer.
  class ErrorSerializer < ErrorEntry
    required_option :param

    attribute(:code, unless: -> { !error.type.is_a?(Symbol) }) { error_code }
    attribute(:detail) { error.full_message }
    attribute(:source, unless: -> { error.attribute.nil? || error.attribute == :base }) do
      {pointer: "/#{param}/#{attribute_as_pointer}"}
    end

    private

    def attribute_as_pointer
      error.attribute.to_s.gsub(/\[(\d+)\]/, '/\1').tr(".", "/")
    end

    def error_code
      (error.attribute == :base) ? error.type.to_s : "#{error.attribute}_#{error.type}"
    end
  end
end
