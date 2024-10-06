# frozen_string_literal: true

module Halitosis
  class Error < StandardError; end

  ### Configuration Errors ###

  class InvalidCollection < StandardError; end

  class InvalidField < StandardError; end

  class InvalidResource < StandardError; end

  ### Rendering Errors ###

  class InvalidQueryParameter < Error
    def initialize(message, parameter)
      @parameter = parameter
      super(message)
    end

    attr_reader :parameter
  end
end
