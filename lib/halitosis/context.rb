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

    # Like call_instance but forwards args instead of the context
    #
    def call_instance_with(*args, guard)
      case guard
      when Proc
        instance.instance_exec(*args, &guard)
      when Symbol, String
        instance.send(guard, *args)
      else
        guard
      end
    end

    # Evaluate :if/:unless conditional options against the serializer instance
    #
    def call_conditional?(options)
      if options.key?(:if)
        !!call_instance(options.fetch(:if))
      elsif options.key?(:unless)
        !call_instance(options.fetch(:unless))
      else
        true
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

    # @return [nil, Hash] the shared included resources registry, if collect_includes is active
    #
    def included_registry
      if parent
        parent.included_registry
      elsif instance.respond_to?(:collect_includes_registry)
        instance.collect_includes_registry
      end
    end

    ### Query params ###

    # Returns a plain hash of normalized query params accumulated during rendering.
    # Each middleware module (Filterable, Sortable, Includeable) contributes its
    # slice by calling +register_query_params+.
    #
    # @return [Hash]
    #
    def query_params
      (@query_params_registry || {}).freeze
    end

    # Merge +hash+ into the accumulated query params registry.
    #
    # @param hash [Hash]
    #
    def register_query_params(hash)
      @query_params_registry = (@query_params_registry || {}).merge(hash)
    end

    ### Hierarchy ###

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

    # Returns true when a root envelope should be rendered.
    #
    # @return [Boolean]
    #
    def include_root?
      !!fetch(:include_root) { depth.zero? }
    end

    private

    attr_reader :instance, :options
  end
end
