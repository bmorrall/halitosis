# frozen_string_literal: true

module Halitosis
  module Relationships
    class Field < Halitosis::Field
      # @return [true] if nothing is raised
      #
      # @raise [Halitosis::InvalidField] if the definition is invalid
      #
      def validate
        super

        return true if procedure

        raise InvalidField, "Relationship #{name} must be defined with a proc"
      end

      # Check whether this definition should be included for the given instance
      #
      # @param instance [Object]
      #
      # @return [true, false]
      #
      def enabled?(instance)
        return false unless super

        opts = instance.include_options

        # Field name must appear in instance included option keys
        return false unless opts.include?(name.to_s)

        # Check value of included option for definition name
        !%w[0 false].include?(opts.fetch(name.to_s).to_s)
      end
    end
  end
end
