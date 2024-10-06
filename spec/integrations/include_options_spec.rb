RSpec.describe "Include Options" do
  context "with a simple resource with a relationship, items array, and items collection" do
    let(:klass) do
      Class.new do
        include Halitosis

        attribute(:verify_depth) { |ctx| ctx.depth }
        attribute(:verify_include) { |ctx| ctx.include_options.keys }

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
      serializer = klass.new

      expect(serializer.render).to eq(verify_depth: 0, verify_include: [])
    end

    it "allows child resources to be included" do
      serializer = klass.new(include: {item: true})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["item"],
        _relationships: {item: {verify_depth: 1, verify_include: []}}
      )
    end

    it "allows child items_array to be included" do
      serializer = klass.new(include: {items_array: true})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["items_array"],
        _relationships: {items_array: [{verify_depth: 1, verify_include: []}]}
      )
    end

    it "allows child items_collection to be included" do
      serializer = klass.new(include: {items_collection: true})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["items_collection"],
        _relationships: {items_collection: [{verify_depth: 2, verify_include: []}]}
      )
    end

    it "allows grandchild resources to be included from a child resource" do
      serializer = klass.new(include: {item: {item: true}})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["item"],
        _relationships: {
          item: {
            verify_depth: 1,
            verify_include: ["item"],
            _relationships: {item: {verify_depth: 2, verify_include: []}}
          }
        }
      )
    end

    it "allows grandchild resources to be included from a resource array" do
      serializer = klass.new(include: {items_array: {item: true}})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["items_array"],
        _relationships: {
          items_array: [
            {
              verify_depth: 1,
              verify_include: ["item"],
              _relationships: {item: {verify_depth: 2, verify_include: []}}
            }
          ]
        }
      )
    end

    it "allows grandchild resources to be included from a resource collection" do
      serializer = klass.new(include: {items_collection: {item: true}})
      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["items_collection"],
        _relationships: {
          items_collection: [
            {
              verify_depth: 2,
              verify_include: ["item"],
              _relationships: {item: {verify_depth: 3, verify_include: []}}
            }
          ]
        }
      )
    end

    it "allows grandchild items_array to be included from a child resource" do
      serializer = klass.new(include: {item: {items_array: true}})
      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["item"],
        _relationships: {
          item: {
            verify_depth: 1,
            verify_include: ["items_array"],
            _relationships: {items_array: [{verify_depth: 2, verify_include: []}]}
          }
        }
      )
    end

    it "allows grandchild items_array to be included from a resource array" do
      serializer = klass.new(include: {items_array: {items_array: true}})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["items_array"],
        _relationships: {
          items_array: [
            {
              verify_depth: 1,
              verify_include: ["items_array"],
              _relationships: {items_array: [{verify_depth: 2, verify_include: []}]}
            }
          ]
        }
      )
    end

    it "allows grandchild items_array to be included from a resource collection" do
      serializer = klass.new(include: {items_collection: {items_array: true}})
      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["items_collection"],
        _relationships: {
          items_collection: [
            {
              verify_depth: 2,
              verify_include: ["items_array"],
              _relationships: {items_array: [{verify_depth: 3, verify_include: []}]}
            }
          ]
        }
      )
    end

    it "allows child resources and items_array to be included" do
      serializer = klass.new(include: {item: true, items_array: true})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["item", "items_array"],
        _relationships: {
          item: {verify_depth: 1, verify_include: []},
          items_array: [{verify_depth: 1, verify_include: []}]
        }
      )
    end

    it "raises an error when an unknown key is included" do
      expect {
        klass.new(include: {goose: true}).render
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidQueryParameter)
        expect(exception.message).to eq("The resource does not have a `goose` relationship path.")
      end
    end

    it "raises an error when an unknown key is included in a child resource" do
      expect {
        klass.new(include: {item: {goose: true}}).render
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidQueryParameter)
        expect(exception.message).to eq("The resource does not have a `goose` relationship path.")
      end
    end

    it "uses the resource type in the error message" do
      klass.resource(:example)

      expect {
        klass.new(nil, include: {goose: true}).render
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidQueryParameter)
        expect(exception.message).to eq("The example resource does not have a `goose` relationship path.")
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

              attribute(:verify_depth) { |ctx| ctx.depth }
              attribute(:verify_include) { |ctx| ctx.include_options.keys }

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

        attribute(:verify_depth) { |ctx| ctx.depth }
        attribute(:verify_include) { |ctx| ctx.include_options.keys }
      end
    end

    it "excludes relationships by default" do
      serializer = klass.new([])

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: [],
        items: [{verify_depth: 1, verify_include: []}]
      )
    end

    it "allows child resources to be included" do
      serializer = klass.new([], include: {item: true})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["item"],
        items: [{
          verify_depth: 1,
          verify_include: ["item"],
          _relationships: {item: {verify_depth: 2, verify_include: []}}
        }]
      )
    end

    it "allows child items_array to be included" do
      serializer = klass.new([], include: {items_array: true})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["items_array"],
        items: [{
          verify_depth: 1,
          verify_include: ["items_array"],
          _relationships: {items_array: [{verify_depth: 2, verify_include: []}]}
        }]
      )
    end

    it "allows child items_collection to be included" do
      serializer = klass.new([], include: {items_collection: true})

      expect(serializer.render).to eq(
        verify_depth: 0,
        verify_include: ["items_collection"],
        items: [{
          verify_depth: 1,
          verify_include: ["items_collection"],
          _relationships: {items_collection: [{verify_depth: 3, verify_include: []}]}
        }]
      )
    end

    it "raises an error for unknown keys on the root collection" do
      expect {
        klass.new([], include: {goose: true}).render
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidQueryParameter)
        expect(exception.message).to eq("The resource does not have a `goose` relationship path.")
      end
    end
  end
end
