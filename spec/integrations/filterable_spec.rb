# frozen_string_literal: true

RSpec.describe "Filterable" do
  let :item_klass do
    Class.new do
      include Halitosis

      resource :item

      attribute(:name) { resource[:name] }
      attribute(:score) { resource[:score] }
    end
  end

  let :klass do
    item_ser = item_klass

    Class.new do
      include Halitosis

      collection :items do
        collection.map { |i| item_ser.new(i) }
      end

      filterable_by :name do |value|
        collection.select { |i| i[:name] == value }
      end

      filterable_by :score do |value|
        integer_value = Integer(value)
        collection.select { |i| i[:score] == integer_value }
      rescue ArgumentError, TypeError
        nil
      end
    end
  end

  let(:items) do
    [
      {name: "Alice", score: 1},
      {name: "Bob", score: 2},
      {name: "Alice", score: 3}
    ]
  end

  def rendered_names(result)
    result[:items].map { |i| i[:name] }
  end

  def rendered_scores(result)
    result[:items].map { |i| i[:score] }
  end

  context "without a filter param" do
    it "renders the full collection" do
      serializer = klass.new(items)

      expect(rendered_names(serializer.render)).to eq(%w[Alice Bob Alice])
    end
  end

  context "filtering by name" do
    it "returns only items matching the name" do
      serializer = klass.new(items, filter: {name: "Alice"})

      expect(rendered_names(serializer.render)).to eq(%w[Alice Alice])
    end

    it "returns an empty items list when no items match" do
      serializer = klass.new(items, filter: {name: "Charlie"})

      expect(serializer.render[:items]).to eq([])
    end
  end

  context "filtering by score" do
    it "returns only items with the matching score" do
      serializer = klass.new(items, filter: {score: "2"})

      expect(rendered_names(serializer.render)).to eq(["Bob"])
      expect(rendered_scores(serializer.render)).to eq([2])
    end
  end

  context "filtering with multiple keys (AND logic)" do
    it "applies both filters in sequence" do
      serializer = klass.new(items, filter: {name: "Alice", score: "1"})

      result = serializer.render[:items]
      expect(result.size).to eq(1)
      expect(result.first[:name]).to eq("Alice")
      expect(result.first[:score]).to eq(1)
    end
  end

  context "with an invalid filter value (nil block return)" do
    it "raises InvalidFilterParameter" do
      serializer = klass.new(items, filter: {score: "not_a_number"})

      expect { serializer.render }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
        expect(exception.message).to match(/can not be filtered by 'score' with the provided value/i)
        expect(exception.parameter).to eq("filter")
      end
    end
  end

  context "with an unknown filter key" do
    it "raises InvalidFilterParameter" do
      serializer = klass.new(items, filter: {unknown: "x"})

      expect { serializer.render }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
        expect(exception.message).to match(/can not be filtered by 'unknown'/)
        expect(exception.parameter).to eq("filter")
      end
    end
  end

  context "combined with sorting" do
    before do
      klass.sortable_by(:name) { |asc| asc ? collection.sort_by { |i| i[:name] } : collection.sort_by { |i| i[:name] }.reverse }
    end

    it "filters first, then sorts the filtered result" do
      serializer = klass.new(items, filter: {name: "Alice"}, sort: "-name")

      # After filtering: [{name: "Alice", score: 1}, {name: "Alice", score: 3}]
      # After sort by -name (all same name, order determined by original): both Alice
      result = serializer.render[:items]
      expect(result.map { |i| i[:name] }).to all(eq("Alice"))
    end
  end
end
