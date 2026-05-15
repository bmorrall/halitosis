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

    # When +true+ (the default), include paths not declared via +allow_include+ are
    # silently ignored. Set to +false+ to raise +InvalidIncludeParameter+ for any
    # include path that was not explicitly declared on the collection serializer.
    #
    # @return [Boolean]
    #
    def allow_undeclared_includes
      return @allow_undeclared_includes unless @allow_undeclared_includes.nil?

      true
    end

    attr_writer :allow_undeclared_includes
  end
end
