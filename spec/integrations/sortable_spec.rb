# frozen_string_literal: true

RSpec.describe "Sortable" do
  # A minimal resource serializer for use inside collection tests
  let :item_klass do
    Class.new do
      include Halitosis

      resource :item

      attribute(:name) { resource[:name] }
      attribute(:length) { resource[:name].length }
    end
  end

  let :klass do
    item_ser = item_klass

    Class.new do
      include Halitosis

      collection :items do
        collection.map { |i| item_ser.new(i) }
      end

      sortable_by :name do |collection, ascending|
        ascending ? collection.sort_by { |i| i[:name] } : collection.sort_by { |i| i[:name] }.reverse
      end

      sortable_by :length do |collection, ascending|
        ascending ? collection.sort_by { |i| i[:name].length } : collection.sort_by { |i| i[:name].length }.reverse
      end
    end
  end

  let(:items) { [item("banana"), item("apple"), item("cherry")] }

  # Helper: build an item hash
  def item(name)
    {name: name}
  end

  # Helper: extract rendered names in order from a result
  def rendered_names(result)
    result[:items].map { |i| i[:name] }
  end

  context "with a single ascending sort field" do
    it "sorts the rendered collection ascending" do
      serializer = klass.new(items, sort: "name")

      expect(rendered_names(serializer.render)).to eq(["apple", "banana", "cherry"])
    end
  end

  context "with a single descending sort field" do
    it "sorts the rendered collection descending" do
      serializer = klass.new(items, sort: "-name")

      expect(rendered_names(serializer.render)).to eq(["cherry", "banana", "apple"])
    end
  end

  context "with multiple sort fields as a comma-separated string" do
    it "applies each field's sort in sequence (last wins)" do
      # sort by length first, then by name — each replaces @collection in turn
      four_items = [item("banana"), item("apple"), item("cherry"), item("date")]
      serializer = klass.new(four_items, sort: "length,name")

      # length sort: date(4), apple(5), banana(6), cherry(6)
      # name sort (applied on that result): apple, banana, cherry, date
      expect(rendered_names(serializer.render)).to eq(["apple", "banana", "cherry", "date"])
    end
  end

  context "with an array of sort params" do
    it "produces the same result as the comma-separated equivalent" do
      string_result = klass.new(items.dup, sort: "name").render
      array_result = klass.new(items.dup, sort: ["name"]).render

      expect(rendered_names(string_result)).to eq(rendered_names(array_result))
    end

    it "handles an array of comma-joined strings" do
      result = klass.new(items.dup, sort: ["-name"]).render

      expect(rendered_names(result)).to eq(["cherry", "banana", "apple"])
    end
  end

  context "when a sortable_by block returns nil for the requested direction" do
    let :ascending_only_klass do
      item_ser = item_klass

      Class.new do
        include Halitosis

        collection :items do
          collection.map { |i| item_ser.new(i) }
        end

        sortable_by :name do |collection, ascending|
          # only supports ascending — returns nil to signal unsupported direction
          collection.sort_by { |i| i[:name] } if ascending
        end
      end
    end

    it "raises InvalidSortParameter with the direction prefix for descending" do
      serializer = ascending_only_klass.new(items, sort: "-name")

      expect { serializer.render }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidSortParameter)
        expect(exception.message).to match(/can not be sorted by '-name'/)
        expect(exception.parameter).to eq("sort")
      end
    end

    it "succeeds for the supported ascending direction" do
      serializer = ascending_only_klass.new(items, sort: "name")

      expect(rendered_names(serializer.render)).to eq(%w[apple banana cherry])
    end
  end

  context "with an unknown sort field" do
    it "raises InvalidSortParameter" do
      serializer = klass.new(items, sort: "unknown")

      expect { serializer.render }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidSortParameter)
        expect(exception.message).to match(/can not be sorted by 'unknown'/)
        expect(exception.parameter).to eq("sort")
      end
    end

    it "reports the first unknown field in a multi-field sort" do
      serializer = klass.new(items, sort: "name,bogus")

      expect { serializer.render }.to raise_error(
        Halitosis::InvalidSortParameter,
        /can not be sorted by 'bogus'/
      )
    end
  end

  context "without a sort param" do
    it "renders the collection in its original order" do
      serializer = klass.new(items)

      expect(rendered_names(serializer.render)).to eq(["banana", "apple", "cherry"])
    end
  end

  context "with default_sort as a string" do
    it "applies the named sort field when no sort param is provided" do
      klass.default_sort("name")

      expect(rendered_names(klass.new(items).render)).to eq(["apple", "banana", "cherry"])
    end

    it "is overridden when a sort param is explicitly provided" do
      klass.default_sort("name")

      expect(rendered_names(klass.new(items, sort: "-name").render)).to eq(["cherry", "banana", "apple"])
    end

    it "raises InvalidQueryParameter if the default references an unknown field" do
      unknown_klass = Class.new do
        include Halitosis

        collection :items do
          collection
        end

        default_sort "unknown"
      end

      expect { unknown_klass.new([]).render }.to raise_error(
        Halitosis::InvalidSortParameter,
        /can not be sorted by 'unknown'/
      )
    end
  end

  context "with default_sort as a block" do
    it "applies the block when no sort param is provided" do
      klass.default_sort { collection.reverse }

      expect(rendered_names(klass.new(items).render)).to eq(["cherry", "apple", "banana"])
    end

    it "is overridden when a sort param is explicitly provided" do
      klass.default_sort { collection.reverse }

      expect(rendered_names(klass.new(items, sort: "name").render)).to eq(["apple", "banana", "cherry"])
    end
  end

  context "with render options forwarded through render_with_params" do
    it "passes the sort param through to the serializer", :rails do
      params = ActionController::Parameters.new(sort: "-name")

      serializer = klass.new(items)

      expect(rendered_names(serializer.render_with_params(params))).to eq(["cherry", "banana", "apple"])
    end
  end
end
