module Halitosis
  # Provide Rails-specific extensions if loaded in a Rails application
  #
  class Railtie < ::Rails::Railtie
    initializer "halitosis.i18n" do
      I18n.load_path += Dir[File.join(__dir__, "locales", "*.yml")]
    end

    module Renderable
      # Render this serializer using params from a request.
      #
      # Supports both JSON:API nested pagination params (+page[number]+/+page[size]+)
      # and the legacy flat style (+page+ / +per_page+) as a fallback.
      #
      def render_with_params(params)
        page = params[:page]
        page_hash = page.respond_to?(:each_pair) ? {number: page[:number], size: page[:size]} : {number: page, size: params[:per_page]}

        render(
          fields: params[:fields],
          filter: params[:filter],
          include: params[:include],
          page: page_hash,
          sort: params[:sort]
        )
      end

      def render_in(view_context, **)
        rendered = render_with_params(view_context.params)
        view_context.render plain: rendered.to_json
      end

      def format
        :json
      end
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
