module Halitosis
  # Provide Rails-specific extensions if loaded in a Rails application
  #
  class Railtie < ::Rails::Railtie
    module Renderable
      def render_in(view_context)
        view_context.render json: self
      end

      def format
        :json
      end
    end

    initializer "halitosis.url_helpers" do |_app|
      Halitosis.config.extensions << ::Rails.application.routes.url_helpers
    end

    initializer "halitosis.renderable" do |_app|
      Halitosis.config.extensions << Renderable
    end
  end
end
