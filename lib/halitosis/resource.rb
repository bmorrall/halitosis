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
    end
  end
end

require "halitosis/resource/field"
