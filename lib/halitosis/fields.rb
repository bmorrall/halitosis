# frozen_string_literal: true

module Halitosis
  # Each serializer class has a Fields object that stores the fields that have been defined on it.
  #
  # Fields must only be created at DSL time (class definition), never at instance or render time.
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

    # Returns the first field of +type+ whose +name+ matches +field_name+,
    # or +nil+ if none is found.
    #
    # @param type [Class]
    # @param field_name [Symbol, String]
    # @return [Halitosis::Field, nil]
    #
    def find_by_name(type, field_name)
      for_type(type).find { |f| f.name.to_s == field_name.to_s }
    end

    # Returns the value stored for the given type key, or +nil+ if nothing
    # has been registered under that key.
    #
    # @param type [Class]
    # @return [Halitosis::Field, nil]
    #
    def singleton(type)
      self[type.name]
    end

    # Registers a field that may only exist once per class. Raises
    # +Halitosis::InvalidField+ if any field of the same type has already been
    # registered, whether via +add+ or +add_singleton+.
    #
    # @param field [Halitosis::Field]
    # @return [Halitosis::Field]
    # @raise [Halitosis::InvalidField]
    #
    def add_singleton(field)
      key = field.class.name

      if key?(key)
        raise Halitosis::InvalidField, "#{field.class.name} is already defined"
      end

      field.validate
      field.freeze

      self[key] = field
    end
  end
end
