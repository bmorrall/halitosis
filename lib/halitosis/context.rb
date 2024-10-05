module Halitosis
  class Context
    # @param instance [Halitosis::Base] the serializer instance
    # @param options [Hash] hash of options
    def initialize(instance, options = {})
      @instance = instance
      @options = HashUtil.symbolize_hash(options).freeze
    end

    ### Instance ###

    # Evaluate guard procedure or method on the serializer instance
    #
    def call_instance(guard)
      case guard
      when Proc
        instance.instance_exec(self, &guard)
      when Symbol, String
        instance.send(guard)
      else
        guard
      end
    end

    ### Options ###

    def fetch(...)
      options.fetch(...)
    end

    # @return [Hash] hash of options with top level string keys
    #
    def include_options
      @include_options ||= HashUtil.hasherize_include_option(options[:include] || {})
    end

    # @return [nil, Halitosis::Context] the parent context, if this instance is an
    #   embedded child
    #
    def parent
      options.fetch(:parent, nil)
    end

    # @return [Integer] the depth at which this serializer is embedded
    #
    def depth
      @depth ||= parent ? parent.depth + 1 : 0
    end

    private

    attr_reader :instance, :options
  end
end
