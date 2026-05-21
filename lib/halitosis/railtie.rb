module Halitosis
  # Provide Rails-specific extensions if loaded in a Rails application
  #
  class Railtie < ::Rails::Railtie
    initializer "halitosis.i18n" do
      I18n.load_path += Dir[File.join(__dir__, "locales", "*.yml")]
    end

    initializer "halitosis.url_helpers" do |_app|
      Halitosis.config.extensions << ::Rails.application.routes.url_helpers
    end

    initializer "halitosis.error_response" do
      ActionDispatch::ExceptionWrapper.rescue_responses.reverse_merge!(
        InvalidPaginationParameter.name => :bad_request,
        InvalidQueryParameter.name => :bad_request,
        InvalidSortParameter.name => :bad_request,
        InvalidIncludeParameter.name => :bad_request,
        InvalidFilterParameter.name => :bad_request
      )
    end

    initializer "halitosis.renderable" do |_app|
      Halitosis.config.extensions << Renderable
    end
  end
end

require_relative "error_handling"
require_relative "rails/renderable"
require_relative "rails/error_serializer"
require_relative "rails/errors_serializer"
require_relative "rails/exception_serializer"
require_relative "rails/parameter_exception_serializer"
