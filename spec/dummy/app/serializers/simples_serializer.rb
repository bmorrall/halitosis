class SimplesSerializer
  include Halitosis

  collection(:simples) do
    simples.map { |simple_example| SimpleSerializer.new(simple_example) }
  end
end
