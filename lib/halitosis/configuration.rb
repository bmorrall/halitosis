module Halitosis
  # Simple configuration class
  #
  class Configuration
    # Array of extension modules to be included in all serializers
    #
    # @return [Array<Module>]
    #
    def extensions
      @extensions ||= []
    end

    # Default pagination adapter used by +paginate_links+ when no per-serializer
    # adapter is specified. Accepted values: +:kaminari+, +:will_paginate+, or
    # any callable that responds to +call(context, collection)+.
    #
    # @return [Symbol, #call, nil]
    #
    attr_accessor :pagination_adapter
  end
end
