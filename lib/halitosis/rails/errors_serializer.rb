# frozen_string_literal: true

module Halitosis
  # Serializes an ActiveModel::Errors collection into a JSON-compatible errors
  # array, following a JSON:API-inspired structure:
  #
  #   {
  #     errors: [
  #       {
  #         id: "title_blank",
  #         detail: "Title can't be blank",
  #         source: { pointer: "/title" }
  #       }
  #     ]
  #   }
  #
  # The `id` field is derived from the error attribute and type (e.g.
  # `"title_blank"`), and is omitted when the error type is not a Symbol.
  #
  # The `source.pointer` field is a JSON Pointer to the offending attribute.
  # Pass `param:` to scope the pointer under a named parameter namespace
  # (e.g. `param: "article"` produces `"/article/title"`).
  # Base errors (attribute == :base) omit both `id` and `source.pointer`.
  #
  # @example Basic usage
  #   ErrorsSerializer.new(record.errors).as_json
  #
  # @example Scoped under a param
  #   ErrorsSerializer.new(record.errors, param: "article").as_json
  #
  # @example As a Rails renderable
  #   render renderable: ErrorsSerializer.new(record.errors), status: :unprocessable_entity
  #
  class ErrorsSerializer
    # @param errors [ActiveModel::Errors]
    # @param param [nil, String] optional namespace for source pointer paths
    def initialize(errors, param: nil)
      @errors = errors
      @param = param
    end

    # @return [Hash]
    def as_json(...)
      {
        errors: errors.map { |error| serialize_error(error) }
      }.as_json(...)
    end

    # Rails renderable protocol — renders the errors as JSON with the correct
    # content type when used with `render renderable:`.
    #
    # @example In a controller action
    #   def create
    #     if @article.save
    #       render renderable: ArticleSerializer.new(@article), status: :created
    #     else
    #       render renderable: Halitosis::ErrorsSerializer.new(@article.errors), status: :unprocessable_entity
    #     end
    #   end
    #
    # @param view_context [ActionView::Base]
    def render_in(view_context)
      view_context.render plain: as_json.to_json
    end

    # Rails renderable protocol — signals that this object renders as JSON.
    #
    # @return [Symbol]
    def format
      :json
    end

    private

    attr_reader :errors, :param

    # Builds a hash for a single error, omitting nil fields.
    #
    # @param error [ActiveModel::Error]
    # @return [Hash]
    def serialize_error(error)
      hash = {detail: error.full_message}
      id = attribute_error_id(error)
      hash[:id] = id if id
      pointer = attribute_pointer(error)
      hash[:source] = {pointer: pointer} if pointer
      hash
    end

    # Builds a machine-readable error id from the attribute and type.
    # Returns nil when the type is not a Symbol (e.g. a custom message string).
    #
    # @param error [ActiveModel::Error]
    # @return [nil, String]
    def attribute_error_id(error)
      return nil unless error.type.is_a?(Symbol)

      (error.attribute == :base) ? error.type.to_s : [error.attribute, error.type].join("_")
    end

    # Builds a JSON Pointer to the offending attribute.
    # Returns nil for base errors and errors without an attribute.
    #
    # @param error [ActiveModel::Error]
    # @return [nil, String]
    def attribute_pointer(error)
      return if error.attribute == :base || !error.attribute

      param ? "/#{param}/#{error.attribute}" : "/#{error.attribute}"
    end
  end
end
