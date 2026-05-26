# frozen_string_literal: true

module Halitosis
  # Provides user-defined prechecks for a serializer.
  #
  # Prechecks are blocks registered with +precheck+ at class-definition time.
  # They are stored as named +Precheck::Field+ entries in the serializer's
  # +fields+ collection — each name must be unique within a class.
  # They execute on the serializer instance at the root render level only —
  # before +before_render+ or any other rendering callbacks fire. Use methods
  # from +Halitosis::Raises+ inside the block to surface errors.
  #
  # @example
  #   class ArticleSerializer
  #     include Halitosis
  #     resource :article
  #
  #     precheck :validate_status do |opts|
  #       raise_invalid_filter_parameter("status") unless valid_status?(opts[:filter]&.dig(:status))
  #     end
  #   end
  #
  module Precheck
    def self.included(base)
      base.extend ClassMethods

      base.send :include, InstanceMethods
    end

    # A field type that stores a single precheck block.
    # Keyed by name inside the shared +fields+ collection.
    #
    class Field < Halitosis::Field
      # Execute the precheck block on the serializer instance,
      # passing the render params hash as the first block argument.
      #
      # @param context [Halitosis::Context]
      #
      def execute(context)
        context.call_instance(context.query_params, procedure)
      end

      def validate
        raise Halitosis::InvalidField, "precheck :#{name} requires a block" unless procedure

        true
      end
    end

    module ClassMethods
      # Register a named precheck block to run before rendering begins.
      # The name must be unique within the serializer class; reusing a name
      # replaces the existing precheck (consistent with field semantics).
      # Prechecks only run at the root render level.
      #
      # @param name [Symbol, String] unique name for this precheck
      # @yieldparam nothing — the block is evaluated on the serializer instance
      # @raise [Halitosis::InvalidField] if no block is given
      #
      def precheck(name, &procedure)
        fields.add(Precheck::Field.new(name, {}, procedure))
      end
    end

    module InstanceMethods
      private

      # Execute all registered prechecks on the serializer instance.
      #
      # @param context [Halitosis::Context]
      #
      def run_prechecks!(context)
        self.class.fields.for_type(Precheck::Field).each do |field|
          field.execute(context)
        end
      end
    end
  end
end
