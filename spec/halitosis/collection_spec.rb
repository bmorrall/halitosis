# frozen_string_literal: true

RSpec.describe Halitosis::Collection do
  let :klass do
    Class.new do
      include Halitosis
      include Halitosis::Collection
    end
  end

  describe ".included" do
    it "raises error if base is already a resource" do
      resource_class = Class.new do
        include Halitosis
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
      it "renders the collection key as the first key" do
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
    end
  end
end
