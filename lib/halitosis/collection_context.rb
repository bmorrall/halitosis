# frozen_string_literal: true

module Halitosis
  # A Context subclass for collection serializers that carries the working
  # collection through the render pipeline.
  #
  # The collection is initialised to +nil+ at construction time and assigned
  # immediately after by +Collection::InstanceMethods#build_context+, once the
  # context object is fully constructed. Sort and filter modules then replace
  # +collection+ in place rather than mutating the serializer instance.
  #
  class CollectionContext < Context
    def initialize(instance, options = {})
      super
      @collection = nil
    end

    attr_accessor :collection

    def collection?
      true
    end
  end
end
