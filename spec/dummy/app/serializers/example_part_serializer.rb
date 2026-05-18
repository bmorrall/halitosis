class ExamplePartSerializer
  include Halitosis

  resource :part

  attribute :name

  # Must be declared so that include=parts.detail passes validate_relationships!
  # on this child serializer. The allow_include :detail block on the parent
  # handles eager loading; this relationship renders whatever the preloaded
  # resource exposes.
  relationship :detail do
    nil
  end
end
