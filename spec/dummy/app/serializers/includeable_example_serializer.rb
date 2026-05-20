class IncludeableExampleSerializer
  include Halitosis

  resource :example

  attribute :id

  relationship :parts, preload: :example_parts do |_, parts|
    (parts || []).map { |part| ExamplePartSerializer.new(part) }
  end

  allow_include :parts do
    allow_include(:detail) { |parts| parts.map { |p| Example.new(id: p.id, name: "#{p.name} (detailed)") } }
  end

  def example_parts
    [
      Example.new(id: 101, name: "Part A"),
      Example.new(id: 102, name: "Part B")
    ]
  end
end
