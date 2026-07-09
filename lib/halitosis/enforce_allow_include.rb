# frozen_string_literal: true

module Halitosis
  # Shared class-level DSL for opting into strict include enforcement.
  #
  # When enabled on a serializer, any requested include path (top-level or
  # nested) that does not have a corresponding +allow_include+ declaration is
  # treated as if the relationship does not exist, raising
  # +Halitosis::InvalidIncludeParameter+.
  #
  # Included by both +Halitosis::ResourceIncludes+ and
  # +Halitosis::CollectionIncludeable+; each provides its own render-time
  # traversal that consults +enforce_allow_include?+.
  #
  module EnforceAllowInclude
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # Enable strict include enforcement for this serializer.
      #
      # @return [void]
      #
      def enforce_allow_include!
        @enforce_allow_include = true
      end

      # @return [Boolean] whether strict include enforcement is enabled
      #
      def enforce_allow_include?
        return @enforce_allow_include if defined?(@enforce_allow_include)

        superclass.respond_to?(:enforce_allow_include?) && superclass.enforce_allow_include?
      end
    end
  end
end
