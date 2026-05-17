# frozen_string_literal: true

module Halitosis
  module Filterable
    # Builder used when a zero-arity block is passed to +filterable_by+.
    # Evaluates the block in its own context, allowing nested +filterable_by+
    # calls that register fields with dot-prefixed names on the target class.
    #
    # @example
    #   filterable_by :user do
    #     filterable_by :name do |collection, value|
    #       collection.joins(:user).where(users: { name: value })
    #     end
    #   end
    #
    # This registers a single +Filterable::Field+ with name +"user.name"+,
    # which matches both +filter[user][name]=Alice+ and +filter[user.name]=Alice+.
    #
    class Namespace
      # @param prefix [String] dot-notation prefix for all fields declared inside this namespace
      # @param target_class [Class] the serializer class fields are registered on
      #
      def initialize(prefix, target_class)
        @prefix = prefix.to_s
        @target_class = target_class
      end

      # Mirrors +ClassMethods#filterable_by+ within a namespace context.
      #
      # @param name [Symbol, String]
      # @param options [Hash]
      #
      def filterable_by(name, options = {}, &procedure)
        full_name = "#{prefix}.#{name}"

        case procedure&.arity
        when 0
          Namespace.new(full_name, target_class).instance_eval(&procedure)
        when 2
          target_class.fields.add(Filterable::Field.new(full_name, options, procedure))
        when nil
          raise InvalidField, "Filter field #{full_name} must be defined with a proc"
        else
          raise InvalidField,
            "Filter field #{full_name} block must accept 0 arguments (namespace) or 2 arguments (collection, filter value)"
        end
      end

      private

      attr_reader :prefix, :target_class
    end
  end
end
