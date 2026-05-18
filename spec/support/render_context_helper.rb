# frozen_string_literal: true

module RenderContextHelper
  # Run the full render pipeline on +serializer+ and return the populated context.
  #
  # Builds the context, fires +before_render+ (filters/sorts/pagination/preloads),
  # then calls +render_with_context+. Returns the context so callers can inspect
  # +query_params+, +collection+, etc. after the fact.
  #
  def render_context(serializer)
    context = serializer.send(:build_context)
    serializer.before_render(context)
    serializer.render_with_context(context)
    context
  end
end

RSpec.configure do |config|
  config.include RenderContextHelper
end
