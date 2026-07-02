# frozen_string_literal: true

module Halitosis
  module ResourceRelationships
    def self.included(base)
      base.extend ClassMethods

      base.send :include, ResourcePreloader

      base.send :include, InstanceMethods
    end

    module ClassMethods
      # @param name [Symbol, String]
      # @param options [nil, Hash]
      #
      # @return [Halitosis::ResourceRelationships::Field]
      #
      def relationship(name, options = {}, &procedure)
        link_value = options.delete(:link)

        preload_option = options.key?(:preload) ? options.delete(:preload) : nil
        preload_option = true if preload_option.nil? && procedure&.arity&.nonzero?

        condition_opts = {}
        condition_opts[:if] = options[:if] if options.key?(:if)
        condition_opts[:unless] = options[:unless] if options.key?(:unless)

        preload_key = setup_relationship_preload(name.to_sym, preload_option, **condition_opts)

        field = ResourceRelationships::Field.new(name, options, procedure)

        if link_value
          link_opts = {}
          link_opts[:if] = options[:if] if options.key?(:if)
          link_opts[:unless] = options[:unless] if options.key?(:unless)

          link_opts[:preload_key] = preload_key if preload_key

          if link_value.is_a?(Proc)
            # Lambdas enforce arity; wrap so the preloaded value is forwarded correctly.
            # For n-arity lambdas, forward the preloaded value as the sole argument.
            if link_value.lambda?
              captured = link_value
              link_value = if captured.arity != 0
                proc { |preloaded| instance_exec(preloaded, &captured) }
              else
                captured
              end
            end
            link(name, link_opts, &link_value)
          else
            link(name, link_opts.merge(value: link_value))
          end
        end

        fields.add(field)
      end

      alias_method :rel, :relationship

      private

      # Validate the raw +preload:+ option from a +relationship+ declaration,
      # register a preload when appropriate, and return the resolved preload
      # key (or +nil+ when no preload should run).
      #
      # @param name [Symbol] the relationship name
      # @param preload_option [nil, true, false, Symbol, String]
      # @param condition_opts [Hash] +:if:+/+:unless:+ to gate the preload
      # @return [Symbol, nil]
      #
      def setup_relationship_preload(name, preload_option, **condition_opts)
        return nil unless preload_option

        if preload_option != true && !preload_option.is_a?(Symbol) && !preload_option.is_a?(String)
          raise InvalidField, "Relationship #{name} preload option must be a Symbol, String, true, or false"
        end

        preload_key = (preload_option.is_a?(Symbol) || preload_option.is_a?(String)) ? preload_option.to_sym : name.to_sym
        preload(preload_key, as: name, **condition_opts)
        preload_key
      end
    end

    module InstanceMethods
      # @return [Hash] the rendered hash with relationships resources, if any
      #
      def render_with_context(context)
        decorate_render :relationships, context, super
      end

      # Pre-populate the preload cache for all relationship fields that have a
      # registered preload. Only fires for relationship fields that are enabled
      # for the given context.
      #
      # @param context [Halitosis::Context]
      #
      def preload_context(context)
        self.class.fields.for_type(ResourceRelationships::Field).each do |field|
          next unless field.enabled?(context)

          preload_value(context, field.name)
        end

        super
      end

      # @return [Hash] hash of rendered resources to include
      #
      def relationships(context = build_context)
        # Do not validation non-root collections (as they pass values directly to children)
        validate_relationships!(context) unless collection?

        render_fields(ResourceRelationships::Field, context) do |field, result|
          # Use the preload cache if a value has been stored under the field name.
          preloaded = fetch_preload(context, field.name) if preloaded?(context, field.name)
          value = field.value(context, preloaded)

          result[field.name] = relationships_child(field.name.to_s, context, value)
        end
      end

      # @return [nil, Hash, Array<Hash>] either a single rendered child
      #   serializer or an array of them
      #
      def relationships_child(key, context, value)
        return unless value

        opts = child_relationship_opts(key, context)

        if value.is_a?(Array)
          value.map { |item| render_child(item, context, opts) }.compact
        else
          render_child(value, context, opts)
        end
      end

      # @param key [String]
      #
      # @return [Hash]
      #
      def child_relationship_opts(key, context)
        opts = context.include_options.fetch(key, {})

        # Turn { :report => 1 } into { :report => {} } for child
        opts = {} unless opts.is_a?(Hash)

        opts
      end

      private

      def validate_relationships!(context)
        opts = context.include_options.keys.map(&:to_s)

        opts -= self.class.fields.for_type(Field).map { |field| field.name.to_s }

        return if opts.none?

        raise_invalid_include_parameter(opts.first)
      end
    end
  end
end

require "halitosis/resource_relationships/field"
