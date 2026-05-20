RSpec.describe "Include Options" do
  context "with a simple resource with a relationship, items array, and items collection" do
    let(:klass) do
      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        relationship :item do
          self.class.new
        end

        # provides an array of item resources
        relationship :items_array do
          [self.class.new]
        end

        # provides a collection of item resources
        relationship :items_collection do
          item_klass = self.class
          Class.new do
            include Halitosis

            collection :items do
              [item_klass.new]
            end
          end.new([])
        end
      end
    end

    it "excludes relationships by default" do
      expect(klass.new.render).to eq({})
    end

    it "allows child resources to be included" do
      expect(klass.new(include: {item: true}).render).to eq(
        _relationships: {item: {}}
      )
    end

    it "allows child items_array to be included" do
      expect(klass.new(include: {items_array: true}).render).to eq(
        _relationships: {items_array: [{}]}
      )
    end

    it "allows child items_collection to be included" do
      expect(klass.new(include: {items_collection: true}).render).to eq(
        _relationships: {items_collection: [{}]}
      )
    end

    it "allows grandchild resources to be included from a child resource" do
      expect(klass.new(include: {item: {item: true}}).render).to eq(
        _relationships: {
          item: {_relationships: {item: {}}}
        }
      )
    end

    it "allows grandchild resources to be included from a resource array" do
      expect(klass.new(include: {items_array: {item: true}}).render).to eq(
        _relationships: {
          items_array: [{_relationships: {item: {}}}]
        }
      )
    end

    it "allows grandchild resources to be included from a resource collection" do
      expect(klass.new(include: {items_collection: {item: true}}).render).to eq(
        _relationships: {
          items_collection: [{_relationships: {item: {}}}]
        }
      )
    end

    it "allows grandchild items_array to be included from a child resource" do
      expect(klass.new(include: {item: {items_array: true}}).render).to eq(
        _relationships: {
          item: {_relationships: {items_array: [{}]}}
        }
      )
    end

    it "allows grandchild items_array to be included from a resource array" do
      expect(klass.new(include: {items_array: {items_array: true}}).render).to eq(
        _relationships: {
          items_array: [{_relationships: {items_array: [{}]}}]
        }
      )
    end

    it "allows grandchild items_array to be included from a resource collection" do
      expect(klass.new(include: {items_collection: {items_array: true}}).render).to eq(
        _relationships: {
          items_collection: [{_relationships: {items_array: [{}]}}]
        }
      )
    end

    it "allows child resources and items_array to be included" do
      expect(klass.new(include: {item: true, items_array: true}).render).to eq(
        _relationships: {
          item: {},
          items_array: [{}]
        }
      )
    end

    it "raises an error when an unknown key is included" do
      expect {
        klass.new(include: {goose: true}).render
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidIncludeParameter)
        expect(exception.message).to eq("The resource does not have a `goose` relationship path.")
        expect(exception.parameter).to eq("include")
      end
    end

    it "raises an error when an unknown key is included in a child resource" do
      expect {
        klass.new(include: {item: {goose: true}}).render
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidIncludeParameter)
        expect(exception.message).to eq("The resource does not have a `goose` relationship path.")
        expect(exception.parameter).to eq("include")
      end
    end

    it "uses the resource type in the error message" do
      klass.resource(:example)

      expect {
        klass.new(nil, include: {goose: true}).render
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidIncludeParameter)
        expect(exception.message).to eq("The example resource does not have a `goose` relationship path.")
        expect(exception.parameter).to eq("include")
      end
    end
  end

  context "with a collection with a child relationships" do
    let(:klass) do
      Class.new do
        include Halitosis

        collection :items do
          collection_klass = self.class

          [
            Class.new do
              include Halitosis
              include Halitosis::ResourceRelationships

              relationship :item do
                self.class.new
              end

              relationship :items_array do
                [self.class.new]
              end

              relationship :items_collection do
                collection_klass.new([])
              end
            end.new
          ]
        end
      end
    end

    it "excludes relationships by default" do
      expect(klass.new([]).render).to eq(items: [{}])
    end

    it "allows child resources to be included" do
      expect(klass.new([], include: {item: true}).render).to eq(
        items: [{_relationships: {item: {}}}]
      )
    end

    it "allows child items_array to be included" do
      expect(klass.new([], include: {items_array: true}).render).to eq(
        items: [{_relationships: {items_array: [{}]}}]
      )
    end

    it "allows child items_collection to be included" do
      expect(klass.new([], include: {items_collection: true}).render).to eq(
        items: [{_relationships: {items_collection: [{}]}}]
      )
    end

    it "raises an error for unknown keys on the root collection" do
      expect {
        klass.new([], include: {goose: true}).render
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidIncludeParameter)
        expect(exception.message).to eq("The resource does not have a `goose` relationship path.")
        expect(exception.parameter).to eq("include")
      end
    end
  end
end
