# frozen_string_literal: true

module Halitosis
  # Behavior for serializers with a single primary resource
  #
  module Resource
    def self.included(base)
      if base.include?(Collection)
        raise InvalidResource, "#{base.name} has already defined a collection"
      end

      base.extend ClassMethods

      base.send :include, ResourceRelationships
      base.send :include, ResourceIncludes
      base.send :include, InstanceMethods

      base.send :attr_reader, :resource
    end

    module ClassMethods
      # @param name [Symbol, String] name of the resource
      #
      # @return [Module] self
      #
      def define_resource(name)
        self.resource_type = name.to_s

        fields.add_singleton Resource::Field.new(name, {}, nil)

        alias_method name, :resource
      end

      def resource_field
        fields.singleton(Resource::Field) || raise(InvalidField, "#{name || Resource.name} resource is not defined")
      end

      # For resource-based serializers, delegate to the resource by default
      #
      # @param name [Symbol] the field name
      # @return [Proc]
      #
      def default_procedure_for(name)
        proc { resource.public_send(name) }
      end
    end

    module InstanceMethods
      # Override standard initializer to assign primary resource
      #
      # @param resource [Object] the primary resource
      #
      def initialize(resource, **)
        @resource = resource

        super(**)
      end

      # @return [Hash] the rendered hash with resource, as a hash
      #
      def render_with_context(context)
        rendered = super.merge(_type: self.class.resource_type)

        if (key = self.class.resource_field.root_key(context))
          {key => rendered}
        else
          rendered
        end
      end

      private

      # When +value_source+ is a String or Symbol and the serializer instance
      # does not respond to it but the resource does, call it directly on the
      # resource and cache the result. The serializer takes priority; the
      # resource is the fallback. Defers to +super+ for procs and for method
      # names neither object responds to.
      #
      # @param context [Halitosis::Context] the render context
      # @param field_name [Symbol, String] key to store under
      # @param value_source [String, Symbol, Proc] the value to resolve
      #
      def store_preload(context, field_name, value_source)
        if (value_source.is_a?(Symbol) || value_source.is_a?(String)) &&
            !respond_to?(value_source, true) &&
            resource.respond_to?(value_source)
          value = resource.public_send(value_source)
          current = context.fetch_local(:includeable_preloads) || {}

          context.store_local(:includeable_preloads, current.merge(field_name.to_sym => value))
        else
          super
        end
      end
    end
  end
end

require "halitosis/resource/field"
