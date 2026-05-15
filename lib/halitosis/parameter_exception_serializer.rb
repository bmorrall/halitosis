# frozen_string_literal: true

module Halitosis
  class ParameterExceptionSerializer
    def initialize(error)
      @error = error
    end

    def as_json(...)
      {
        errors: [error_hash]
      }.as_json(...)
    end

    private

    attr_reader :error

    def error_hash
      hash = {
        id: translate("id"),
        title: translate("title", default: error.class.name.demodulize.titleize),
        detail: error.message,
        source: source_hash
      }
      hash.compact
    end

    def source_hash
      return unless error.respond_to?(:parameter)

      {parameter: error.parameter}.presence
    end

    def translate(key, **options)
      I18n.t("#{error.class.name}.#{key}", scope: "halitosis.errors", default: nil, **options)
    end
  end
end
