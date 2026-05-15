module Halitosis
  # Provide Rails-specific extensions if loaded in a Rails application
  #
  class Railtie < ::Rails::Railtie
    module Renderable
      def render_with_params(params)
        render(include: params[:include])
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

    initializer "halitosis.error_response" do |app|
      app.config.action_dispatch.rescue_responses[InvalidQueryParameter.name] ||= :bad_request
    end

    initializer "halitosis.renderable" do |_app|
      Halitosis.config.extensions << Renderable
    end
  end
end
