# frozen_string_literal: true

module Halitosis
  # Base module for all serializer classes.
  #
  # Include this module in your serializer class, and include any additional field-type modules
  module Base
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
      base.send :include, Raises
      base.send :include, Precheck

      base.send :attr_reader, :options

      base.class.send :attr_accessor, :resource_type
    end

    module ClassMethods
      # @return [Halitosis::Fields]
      def fields
        @fields ||= Fields.new
      end

      # When a serializer is subclassed, give the child a snapshot copy of the
      # parent's fields so it can add or override fields without affecting the
      # parent class.
      #
      def inherited(subclass)
        super

        child_fields = Fields.new

        fields.each do |key, value|
          child_fields[key] = value.is_a?(Hash) ? value.dup : value
        end

        subclass.instance_variable_set(:@fields, child_fields)
        subclass.resource_type = resource_type if respond_to?(:resource_type)
      end

      # Declares a required initializer option, generating a reader method
      # and raising +MissingOption+ at construction time if absent.
      #
      # @param name [Symbol]
      #
      def required_option(name)
        required_option_keys << name.to_sym
        define_method(name) { options.fetch(name.to_sym) }
      end

      def required_option_keys
        @required_option_keys ||=
          if superclass.respond_to?(:required_option_keys)
            superclass.required_option_keys.dup
          else
            []
          end
      end

      def collection?
        false
      end

      # Returns the default proc used to resolve a field value when no block
      # or :value option is given. Override in submodules to change the source.
      #
      # @param name [Symbol] the field name
      # @return [Proc]
      #
      def default_procedure_for(name)
        proc { public_send(name) }
      end
    end

    module InstanceMethods
      # @param options [nil, Hash] hash of options
      #
      # @return [Object] the serializer instance
      #
      def initialize(**options)
        @options = Halitosis::HashUtil.symbolize_hash(options).freeze

        missing = self.class.required_option_keys.reject { |k| @options.key?(k) }
        raise Halitosis::MissingOption.new(self.class, missing) if missing.any?
      end

      # @return [Hash, Array] rendered JSON
      def as_json(...)
        render.as_json(...)
      end

      # @return [String] rendered JSON
      #
      def to_json(...)
        render.to_json(...)
      end

      # @return [Hash] rendered representation
      #
      def render(**options)
        context = build_context(options)
        run_prechecks!(context) if context.root?
        before_render(context)
        result = render_with_context(context)
        if context.include_root?
          render_root(context.freeze, result)
        else
          result
        end
      end

      # Hook called after the context is built but before rendering begins.
      # Override in submodules or serializer classes to populate preload
      # storage or perform other setup.
      #
      # @param _context [Halitosis::Context]
      #
      def before_render(_context)
      end

      # No-op default; overridden by +Halitosis::Precheck+ when prechecks
      # are registered on the serializer class.
      #
      # @param _context [Halitosis::Context]
      #
      def run_prechecks!(_context)
      end

      # @param context [Halitosis::Context] the context instance
      # @return [Hash] the rendered hash
      #
      def render_with_context(_context)
        {}
      end

      # Called by +render+ after +render_with_context+ when +include_root?+ is
      # true, allowing root-level decoration (links, meta, permissions) with
      # access to the pipeline context. Override in submodules to merge
      # top-level keys into +result+.
      #
      # @param _context [Halitosis::Context]
      # @param result [Hash] the fully-enveloped render output
      # @return [Hash]
      #
      def render_root(_context, result)
        result
      end

      def collection?
        false
      end

      protected

      # Build a new context instance using this serializer instance
      #
      # @return [Halitosis::Context] the context instance
      def build_context(options = {})
        Context.new(self, HashUtil.deep_merge(@options, options))
      end

      # Allow included modules to decorate rendered hash
      #
      # @param key [Symbol] the key (e.g. `embedded`, `links`)
      # @param result [Hash] the partially rendered hash to decorate
      #
      # @return [Hash] the decorated hash
      #
      def decorate_render(key, context, result)
        result.tap do
          value = send(key, context)

          result[:"_#{key}"] = value if value.any?
        end
      end

      # Iterate through enabled fields of the given type, allowing instance
      # to build up resulting hash
      #
      # @param type [Symbol, String] the field type
      #
      # @return [Hash] the result
      #
      def render_fields(type, context)
        fields = self.class.fields.for_type(type)

        fields.each_with_object({}) do |field, result|
          next unless field.enabled?(context)

          yield field, result
        end
      end

      # @param child [Halitosis] the child serializer
      # @param opts [Hash] the include options to assign to the child
      #
      # @return [nil, Hash] the rendered child
      #
      def render_child(child, context, opts)
        return unless child.class.include?(Halitosis::Base)

        child_context = child.build_context(parent: context, include: opts)
        child.before_render(child_context)
        child.render_with_context(child_context)
      end
    end
  end
end
