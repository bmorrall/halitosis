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

      # Override standard attribute field for resource-based serializers
      #
      # @param name [Symbol, String] name of the attribute
      # @param options [nil, Hash] attribute options for field
      #
      def attribute(name, options = {}, &procedure)
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

      # @return [Hash] the rendered hash with resource, as a hash
      #
      def render
        if (include_root = options.fetch(:include_root) { depth.zero? })
          {root_name(include_root, self.class.resource_name) => super}
        else
          super
        end
      end

      private

      def root_name(include_root, default)
        return include_root.to_sym if include_root.is_a?(String) || include_root.is_a?(Symbol)
        default.to_sym
      end
    end
  end
end
