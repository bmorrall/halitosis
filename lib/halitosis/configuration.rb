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
  end
end
