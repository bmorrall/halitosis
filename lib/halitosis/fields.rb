# frozen_string_literal: true

module Halitosis
  # Each serializer class has a Fields object that stores the fields that have been defined on it.
  #
  class Fields < Hash
    def add(field)
      type = field.class.name

      field.validate

      field.freeze

      self[type] ||= []
      self[type] << field

      field
    end

    def for_type(type)
      fetch(type.name, [])
    end
  end
end
