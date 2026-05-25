# frozen_string_literal: true

module Halitosis
  module Renderable
    # Render this serializer using params from a request.
    #
    # Supports both JSON:API nested pagination params (+page[number]+/+page[size]+)
    # and the legacy flat style (+page+ / +per_page+) as a fallback.
    #
    def render_with_params(params)
      page = params[:page]
      page_hash = page.respond_to?(:each_pair) ? {number: page[:number], size: page[:size], after: page[:after], before: page[:before]} : {number: page, size: params[:per_page]}

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
end
