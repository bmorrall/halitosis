RSpec.describe Halitosis::Resource do
  let(:klass) {
    Class.new {
      include Halitosis
      include Halitosis::ResourceRelationships
      include Halitosis::Resource
    }
  }

  describe ".included" do
    it "raises error if base is already a collection" do
      collection_class = Class.new {
        include Halitosis
        include Halitosis::Collection
      }

      expect {
        collection_class.send :include, described_class
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidResource)
        expect(exception.message).to match(/has already defined a collection/i)
      end
    end

    it "declares a resource accessor" do
      resource = double
      serializer = klass.new(resource)
      expect(serializer.resource).to be(resource)
    end
  end

  describe ".define_resource" do
    it "sets a resource type" do
      klass.define_resource(:foo)

      expect(klass.resource_type).to eq("foo")
    end

    it "declares a named resource accessor" do
      resource = double

      klass.define_resource(:foo)

      serializer = klass.new(resource)
      expect(serializer.foo).to be(resource)
    end

    it "handles string arguments" do
      klass.define_resource("foo")

      expect(klass.resource_type).to eq("foo")
    end
  end

  describe "#render" do
    context "with a simple resource" do
      let(:resource) { double }
      let(:serializer) { klass.new(resource) }

      before { klass.resource(:foo) }

      it "renders the response under the resource name" do
        expect(serializer.render).to eq(
          foo: {_type: "foo"}
        )
      end

      it "renders attributes a block under the resource name" do
        klass.attribute(:bar) { "baz" }

        expect(serializer.render).to eq(
          foo: {bar: "baz", _type: "foo"}
        )
      end

      it "renders attributes with a value under the resource name" do
        klass.attribute(:bar, value: "baz")

        expect(serializer.render).to eq(
          foo: {bar: "baz", _type: "foo"}
        )
      end

      it "delegates to the resource for attributes without a value or block" do
        klass.attribute(:bar)

        allow(resource).to receive(:bar).and_return("baz")

        expect(serializer.render).to eq(
          foo: {bar: "baz", _type: "foo"}
        )
      end

      it "delegates to the named resource method when value is a symbol" do
        klass.attribute(:bar, value: :baz)

        allow(resource).to receive(:baz).and_return("qux")

        expect(serializer.render).to eq(
          foo: {bar: "qux", _type: "foo"}
        )
      end

      it "evaluates the block in the context of the serializer" do
        def serializer.bar
          object_id
        end

        klass.attribute(:bar) { bar }

        expect(serializer.render).to eq(
          foo: {bar: serializer.object_id, _type: "foo"}
        )
      end

      it "provides a resource method within the serializer" do
        def serializer.bar
          resource.object_id
        end

        klass.attribute(:bar) { bar }

        expect(serializer.render).to eq(
          foo: {bar: resource.object_id, _type: "foo"}
        )
      end

      it "aliases the resources as the resource name" do
        def serializer.bar
          foo.object_id
        end

        klass.attribute(:bar) { bar }

        expect(serializer.render).to eq(
          foo: {bar: resource.object_id, _type: "foo"}
        )
      end
    end
  end

  describe "#render", "include options" do
    context "with a resource containing a relationship with a resource" do
      before do
        klass.define_resource(:duck)

        klass.attribute(:name, value: "Ferdi")

        klass.relationship(:favourite_food) do
          Class.new {
            include Halitosis

            attribute(:name, value: "bread")
          }.new
        end
      end

      it "excludes resource relationships by default" do
        serializer = klass.new(nil)

        expect(serializer.render).to match(
          duck: {name: "Ferdi", _type: "duck"}
        )
      end

      it "includes resource relationships when requested" do
        serializer = klass.new(nil, include: {favourite_food: true})

        expect(serializer.render).to match(
          duck: {name: "Ferdi", _type: "duck", _relationships: {favourite_food: {name: "bread"}}}
        )
      end
    end

    context "with a resource containing a relationship with a collection" do
      before do
        klass.define_resource(:duck)

        klass.attribute(:name, value: "Ferdi")

        klass.relationship(:favourite_foods) do
          Class.new {
            include Halitosis

            collection(:foods) do
              [
                Class.new {
                  include Halitosis

                  attribute(:name, value: "bread")
                }.new
              ]
            end

            attribute(:mystery, value: "root_only")
          }.new([])
        end
      end

      it "excludes resource relationships by default" do
        serializer = klass.new(nil)

        expect(serializer.render).to match(
          duck: {name: "Ferdi", _type: "duck"}
        )
      end

      it "includes resource relationships when requested" do
        serializer = klass.new(nil, include: {favourite_foods: true})

        expect(serializer.render).to match(
          duck: {name: "Ferdi", _type: "duck", _relationships: {favourite_foods: [{name: "bread"}]}}
        )
      end
    end

    context "with a resource containing child and grandchild relationships" do
      before do
        klass.define_resource(:duck)

        klass.attribute(:name, value: "Ferdi")

        klass.relationship(:favourite_food) do
          Class.new {
            include Halitosis
            include Halitosis::ResourceRelationships

            attribute(:name, value: "bread")

            relationship(:ingredients) do
              [
                Class.new {
                  include Halitosis

                  attribute(:name, value: "flour")
                }.new,
                Class.new {
                  include Halitosis

                  attribute(:name, value: "water")
                }.new
              ]
            end
          }.new
        end
      end

      it "excludes resource relationships by default" do
        serializer = klass.new(nil)

        expect(serializer.render).to match(
          duck: {name: "Ferdi", _type: "duck"}
        )
      end

      it "includes child relationships when requested" do
        serializer = klass.new(nil, include: {favourite_food: true})

        expect(serializer.render).to match(
          duck: {
            name: "Ferdi",
            _type: "duck",
            _relationships: {
              favourite_food: {
                name: "bread"
              }
            }
          }
        )
      end

      it "includes grandchild relationships when requested" do
        serializer = klass.new(nil, include: {favourite_food: {ingredients: true}})

        expect(serializer.render).to match(
          duck: {
            name: "Ferdi",
            _type: "duck",
            _relationships: {
              favourite_food: {
                name: "bread",
                _relationships: {
                  ingredients: [{name: "flour"}, {name: "water"}]
                }
              }
            }
          }
        )
      end
    end
  end

  describe Halitosis::Resource::InstanceMethods do
    let(:resource) { double(resource_method: "resource_value") }

    let(:serializer_klass) do
      Class.new do
        include Halitosis

        resource :item

        def serializer_method
          "serializer_value"
        end
      end
    end

    let(:serializer) { serializer_klass.new(resource) }
    let(:context) { serializer.send(:build_context) }

    describe "#store_preload" do
      context "when value_source is a symbol and only the resource responds to it" do
        it "calls the method on the resource and stores the result" do
          serializer.send(:store_preload, context, :my_field, :resource_method)

          expect(context.fetch_local(:includeable_preloads)).to eq(my_field: "resource_value")
        end
      end

      context "when value_source is a string and only the resource responds to it" do
        it "calls the method on the resource and stores the result" do
          serializer.send(:store_preload, context, :my_field, "resource_method")

          expect(context.fetch_local(:includeable_preloads)).to eq(my_field: "resource_value")
        end
      end

      context "when both the serializer and the resource respond to the method" do
        it "calls the method on the serializer instance, not the resource" do
          allow(resource).to receive(:serializer_method).and_return("resource_override")

          serializer.send(:store_preload, context, :my_field, :serializer_method)

          expect(context.fetch_local(:includeable_preloads)).to eq(my_field: "serializer_value")
        end
      end

      context "when value_source is a symbol the resource does not respond to" do
        it "calls the method on the serializer instance" do
          serializer.send(:store_preload, context, :my_field, :serializer_method)

          expect(context.fetch_local(:includeable_preloads)).to eq(my_field: "serializer_value")
        end
      end

      context "when value_source is a proc" do
        it "evaluates the proc in the context of the serializer instance" do
          serializer.send(:store_preload, context, :my_field, proc { "proc_value" })

          expect(context.fetch_local(:includeable_preloads)).to eq(my_field: "proc_value")
        end
      end
    end
  end
end
