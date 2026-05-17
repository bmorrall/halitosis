class SimplesSerializer
  include Halitosis

  collection(:simples) do |collection|
    collection.map { |simple_example| SimpleSerializer.new(simple_example) }
  end
end
