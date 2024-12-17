class SimpleSerializer
  include Halitosis

  resource :simple

  identifier :id

  attribute :name
end
