module Halitosis
  class Context
    # @param instance [Halitosis::Base] the serializer instance
    # @param options [Hash] hash of options
    def initialize(instance, options = {})
      @instance = instance
      @options = HashUtil.symbolize_hash(options).freeze
    end

    ### Instance ###

    # Evaluate guard procedure or method on the serializer instance,
    # forwarding any leading args to the block or method.
    #
    def call_instance(*args, guard)
      case guard
      when Proc
        instance.instance_exec(*args, &guard)
      when Symbol
        instance.send(guard, *args)
      else
        guard
      end
    end

    # Evaluate :if/:unless conditional options against the serializer instance.
    # Guards that accept an argument receive the context (for root?, depth, etc.).
    #
    def call_conditional?(options)
      if options.key?(:if)
        guard = options.fetch(:if)
        !!call_guard(guard)
      elsif options.key?(:unless)
        guard = options.fetch(:unless)
        !call_guard(guard)
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
      parent ? parent.included_registry : @included_registry
    end

    attr_writer :included_registry

    # Returns the sparse fieldset registry (resource type string → Set of
    # permitted field name strings) shared across the entire render tree.
    # Child contexts delegate to the root so nested resources always see the
    # same registry.
    #
    # @return [Hash{String => Set<String>}, nil]
    #
    def sparse_fields_registry
      parent ? parent.sparse_fields_registry : @sparse_fields_registry
    end

    attr_writer :sparse_fields_registry

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

    # Returns false for plain contexts; overridden in CollectionContext.
    #
    # @return [Boolean]
    #
    def collection?
      false
    end

    # Returns true when this context has no parent (i.e. it is the outermost render).
    #
    # @return [Boolean]
    #
    def root?
      depth.zero?
    end

    # Returns true when a root envelope should be rendered.
    #
    # @return [Boolean]
    #
    def include_root?
      !!fetch(:include_root) { depth.zero? }
    end

    # Store a value in the local context, keyed by +key+. Local data is never
    # propagated to child contexts. Intended for use by field instances only.
    #
    # @param key [Symbol]
    # @param value [Object]
    #
    def store_local(key, value)
      local[key] = value
    end

    # Retrieve a value from the local context by +key+.
    # Intended for use by field instances only.
    #
    # @param key [Symbol]
    # @return [Object, nil]
    #
    def fetch_local(key)
      @local&.[](key)
    end

    private

    attr_reader :instance, :options

    # Calls a conditional guard. Procs/lambdas that accept one argument receive
    # the context so they can query root?, depth, etc.
    #
    def call_guard(guard)
      case guard
      when Proc
        guard.arity.nonzero? ? instance.instance_exec(self, &guard) : instance.instance_exec(&guard)
      when Symbol, String
        instance.send(guard)
      else
        guard
      end
    end

    # A mutable hash for context-local data that is never propagated to child
    # contexts.
    #
    # @return [Hash]
    #
    def local
      @local ||= {}
    end
  end
end
