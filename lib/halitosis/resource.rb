# frozen_string_literal: true

module Halitosis
  # Behavior for serializers with a single primary resource
  #
  module Resource
    def self.included(base)
      if base.included_modules.include?(Collection)
        raise InvalidResource, "#{base.name} has already defined a collection"
      end

      base.extend ClassMethods

      base.send :include, InstanceMethods

      base.send :attr_reader, :resource

      base.class.send :attr_accessor, :resource_name
    end

    module ClassMethods
      # @param name [Symbol, String] name of the resource
      #
      # @return [Module] self
      #
      def define_resource(name)
        self.resource_name = name.to_s

        alias_method name, :resource
      end

      # Override standard property field for resource-based serializers
      #
      # @param name [Symbol, String] name of the property
      # @param options [nil, Hash] property options for field
      #
      def property(name, options = {}, &procedure)
        super.tap do |field|
          unless field.procedure || field.options.key?(:value)
            field.procedure = proc { resource.send(name) }
          end
        end
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
    end
  end
end
