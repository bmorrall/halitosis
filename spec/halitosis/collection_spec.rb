# frozen_string_literal: true

RSpec.describe Halitosis::Collection do
  let :klass do
    Class.new do
      include Halitosis::Base
      include Halitosis::Collection
    end
  end

  describe ".included" do
    it "raises error if base is already a resource" do
      resource_class = Class.new do
        include Halitosis::Base
        include Halitosis::Resource
      end

      expect do
        resource_class.send :include, described_class
      end.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidCollection)
        expect(exception.message).to match(/has already defined a resource/i)
      end
    end
  end

  describe Halitosis::Collection::ClassMethods do
    describe "#define_collection" do
      it "handles string argument" do
        klass.define_collection "ducks" do
          []
        end

        expect(klass.collection_name).to eq("ducks")
      end

      it "handles symbol argument" do
        klass.define_collection :ducks do
          []
        end

        expect(klass.collection_name).to eq("ducks")
      end
    end
  end

  describe Halitosis::Collection::InstanceMethods do
    describe "#collection?" do
      it "is true" do
        serializer = klass.new([])

        expect(serializer.collection?).to eq(true)
      end
    end

    describe "#render" do
      context "with a simple collection" do
        before do
          klass.define_collection :ducks do
            collection
          end
        end

        it "renders attributes on the collection" do
          klass.include Halitosis::Attributes
          klass.attribute :thoughts, value: "food"

          expect(klass.new([]).render).to eq(ducks: [], thoughts: "food")
        end

        it "renders meta on the collection" do
          klass.include Halitosis::Meta
          klass.meta :total, value: 1

          expect(klass.new([]).render).to eq(ducks: [], _meta: {total: 1})
        end

        it "renders links on the collection" do
          klass.include Halitosis::Links
          klass.link :self, value: "http://example.com"

          expect(klass.new([]).render).to eq(ducks: [], _links: {self: {href: "http://example.com"}})
        end

        it "renders permissions on the collection" do
          klass.include Halitosis::Permissions
          klass.permission :read, value: true

          expect(klass.new([]).render).to eq(ducks: [], _permissions: {read: true})
        end
      end

      it "renders the collection key as the first key" do
        klass.send :include, Halitosis # allow other fields to be defined

        # Randomly define a collection with an attribute, meta, link, and permissions
        [
          -> {
            klass.define_collection :ducks do
              []
            end
          },
          -> { klass.attribute :name, value: "Ferdi" },
          -> { klass.meta :total, value: 1 },
          -> { klass.link :self, value: "http://example.com" },
          -> { klass.permission :read, value: true }
        ].shuffle.each(&:call)

        serializer = klass.new([])

        expect(serializer.render.keys.first).to eq(:ducks)
      end

      it "renders simple serializers in the collection array" do
        serializer = Class.new do
          include Halitosis::Base
          include Halitosis::Collection

          define_collection :ducks do
            [
              Class.new do
                include Halitosis

                attribute :name, value: "Ferdi"
              end.new
            ]
          end
        end.new([])

        expect(serializer.render).to eq(ducks: [{name: "Ferdi"}])
      end

      it "renders resources in the collection array" do
        serializer = Class.new do
          include Halitosis::Base
          include Halitosis::Collection

          define_collection :ducks do
            [
              Class.new do
                include Halitosis

                resource :example

                attribute :name, value: "Ferdi"
              end.new(nil)
            ]
          end
        end.new([])

        expect(serializer.render).to eq(ducks: [{name: "Ferdi"}])
      end

      it "renders nested collection without their fields" do
        serializer = Class.new do
          include Halitosis::Base
          include Halitosis::Collection

          define_collection :mallards do
            Class.new do
              include Halitosis

              collection :ducks do
                [
                  Class.new do
                    include Halitosis

                    attribute :name, value: "Ferdi"
                  end.new
                ]
              end

              attribute :thoughts, value: "food"
              meta :total, value: 1
              link :self, value: "/ducks"
              permission :read, value: true
            end.new(collection)
          end
        end.new([])

        expect(serializer.render).to eq(mallards: [{name: "Ferdi"}])
      end

      it "skips primatives in the collection array" do
        serializer = Class.new do
          include Halitosis::Base
          include Halitosis::Collection

          define_collection :ducks do
            [1, "two", true, nil, collection]
          end
        end.new([])

        expect(serializer.render).to eq(ducks: [])
      end

      it "skips collection objects in the collection array" do
        serializer = Class.new do
          include Halitosis::Base
          include Halitosis::Collection

          define_collection :ducks do
            [self.class.new(collection)]
          end
        end.new([])

        expect(serializer.render).to eq(ducks: [])
      end
    end
  end
end
