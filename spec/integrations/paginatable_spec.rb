# frozen_string_literal: true

RSpec.describe "Paginatable" do
  before { allow(Halitosis.config).to receive(:pagination_adapter).and_return(:kaminari) }

  let :item_klass do
    Class.new do
      include Halitosis

      resource :item

      attribute(:id) { resource[:id] }
    end
  end

  let :klass do
    item_ser = item_klass

    Class.new do
      include Halitosis

      collection :items do |collection|
        collection.map { |i| item_ser.new(i) }
      end

      paginate_by_page default_page_size: 10 do |collection, number, size|
        offset = (number - 1) * size
        collection[offset, size] || []
      end
    end
  end

  let(:items) { (1..50).map { |i| {id: i} } }

  def rendered_ids(result)
    result[:items].map { |i| i[:id] }
  end

  context "without page params" do
    it "renders the first page using default_page_size" do
      serializer = klass.new(items)

      expect(rendered_ids(serializer.render)).to eq((1..10).to_a)
    end
  end

  context "when requesting page[number]=2" do
    it "renders the second page" do
      serializer = klass.new(items, page: {number: 2})

      expect(rendered_ids(serializer.render)).to eq((11..20).to_a)
    end
  end

  context "when overriding page[size]" do
    it "renders the requested number of items per page" do
      serializer = klass.new(items, page: {size: 5})

      expect(rendered_ids(serializer.render)).to eq((1..5).to_a)
    end
  end

  context "when providing both page[number] and page[size]" do
    it "paginates correctly" do
      serializer = klass.new(items, page: {number: 3, size: 5})

      expect(rendered_ids(serializer.render)).to eq((11..15).to_a)
    end
  end

  context "when page[number] and page[size] are passed as strings (e.g. from query params)" do
    it "coerces to integers and paginates correctly" do
      serializer = klass.new(items, page: {number: "2", size: "5"})

      expect(rendered_ids(serializer.render)).to eq((6..10).to_a)
    end
  end

  context "when page[number] is an unparseable string" do
    it "raises InvalidPaginationParameter" do
      serializer = klass.new(items, page: {number: "bad"})

      expect { serializer.render }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(exception.message).to match(/can not be paginated with the provided 'page\[number\]' value/i)
      end
    end
  end

  context "when page[size] is an unparseable string" do
    it "raises InvalidPaginationParameter" do
      serializer = klass.new(items, page: {size: "bad"})

      expect { serializer.render }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(exception.message).to match(/can not be paginated with the provided 'page\[size\]' value/i)
      end
    end
  end

  context "when the block returns nil" do
    let :bad_klass do
      Class.new do
        include Halitosis

        collection :items do |collection|
          collection
        end

        paginate_by_page(default_page_size: 10) { |_collection, _number, _size| nil }
      end
    end

    it "raises InvalidPaginationParameter" do
      serializer = bad_klass.new(items)

      expect { serializer.render }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(exception.message).to match(/can not be paginated with the provided values/i)
        expect(exception.parameter).to eq("page")
      end
    end
  end

  context "when combined with filtering" do
    let :filtered_klass do
      item_ser = item_klass

      Class.new do
        include Halitosis

        collection :items do |collection|
          collection.map { |i| item_ser.new(i) }
        end

        filterable_by :min_id do |collection, value|
          collection.select { |i| i[:id] >= value.to_i }
        end

        paginate_by_page default_page_size: 5 do |collection, number, size|
          offset = (number - 1) * size
          collection[offset, size] || []
        end
      end
    end

    it "applies filter first, then paginates the filtered result" do
      # Filter: ids >= 21 (30 items), then take first page of 5
      serializer = filtered_klass.new(items, filter: {min_id: "21"}, page: {size: 5})

      expect(rendered_ids(serializer.render)).to eq((21..25).to_a)
    end
  end
end
