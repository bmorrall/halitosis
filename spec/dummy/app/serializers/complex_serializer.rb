class ComplexSerializer
  include Halitosis

  resource :complex

  identifier :id

  attribute :name

  relationship :single do
    ComplexSerializer.new(Example.new(id: (complex.id * 10) + 1, name: "#{complex.name}-1"))
  end

  relationship :multiple do
    [
      ComplexSerializer.new(Example.new(id: (complex.id * 10) + 1, name: "#{complex.name}-1")),
      ComplexSerializer.new(Example.new(id: (complex.id * 10) + 2, name: "#{complex.name}-2"))
    ]
  end

  root_link(:self) do |_, query_params|
    complex_renderable_path(complex.id, query_params)
  end
end
