# frozen_string_literal: true

module Halitosis
  class ParameterExceptionSerializer < ExceptionSerializer
    class ErrorEntry < ExceptionSerializer::ErrorEntry
      attribute(:code, unless: -> { translate("code").nil? }) { translate("code") }
      attribute(:title) { translate("title", default: error.class.name.demodulize.titleize) }
      attribute(:detail) { error.message }
      attribute(:source, unless: -> { source_hash.nil? }) { source_hash }

      private

      def source_hash
        return unless error.respond_to?(:parameter)

        {parameter: error.parameter}.presence
      end

      def translate(key, **options)
        I18n.t("#{error.class.name}.#{key}", scope: "halitosis.errors", default: nil, **options)
      end
    end

    def initialize(error, **options)
      super(error, error_serializer_class: ErrorEntry, **options)
    end
  end
end
