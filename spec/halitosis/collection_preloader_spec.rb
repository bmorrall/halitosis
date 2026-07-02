# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPreloader do
  let(:items) { [{id: 1}, {id: 2}, {id: 3}] }

  let :klass do
    Class.new do
      include Halitosis

      collection :items do |coll|
        coll.map { |i| i }
      end
    end
  end

  describe Halitosis::CollectionPreloader::ClassMethods do
    describe ".preload" do
      it "registers a CollectionPreloader::Field" do
        klass.preload([:author]) { |coll| coll }

        field = klass.fields.find_by_name(Halitosis::CollectionPreloader::Field, :author)

        expect(field).to be_a(Halitosis::CollectionPreloader::Field)
        expect(field.path).to eq([:author])
      end

      it "stores the path as a dot-joined name for nested paths" do
        klass.preload([:author, :avatar]) { |coll| coll }

        field = klass.fields.find_by_name(Halitosis::CollectionPreloader::Field, :"author.avatar")

        expect(field).not_to be_nil
        expect(field.path).to eq([:author, :avatar])
      end

      it "is idempotent — calling twice does not register a second field" do
        klass.preload([:author]) { |coll| coll }
        klass.preload([:author]) { |coll| coll }

        fields = klass.fields.for_type(Halitosis::CollectionPreloader::Field)

        expect(fields.size).to eq(1)
      end

      it "returns nil" do
        expect(klass.preload([:author]) { |coll| coll }).to be_nil
      end

      it "can be called without a block, registering a nil-procedure field" do
        klass.preload([:author])

        field = klass.fields.find_by_name(Halitosis::CollectionPreloader::Field, :author)

        expect(field).not_to be_nil
      end
    end
  end

  describe Halitosis::CollectionPreloader::InstanceMethods do
    describe "#execute_collection_preload" do
      it "updates context.collection with the result of field.apply" do
        klass.preload([:author]) { |coll| coll + [:extra] }

        field = klass.fields.find_by_name(Halitosis::CollectionPreloader::Field, :author)
        serializer = klass.new([1, 2, 3])
        context = Halitosis::CollectionContext.new(serializer, {})
        context.collection = [1, 2, 3]

        serializer.send(:execute_collection_preload, context, field)

        expect(context.collection).to eq([1, 2, 3, :extra])
      end

      it "does not update context.collection when field.apply returns nil" do
        klass.preload([:author]) { |_coll| nil }

        field = klass.fields.find_by_name(Halitosis::CollectionPreloader::Field, :author)
        serializer = klass.new([1, 2])
        context = Halitosis::CollectionContext.new(serializer, {})
        context.collection = [1, 2]

        serializer.send(:execute_collection_preload, context, field)

        expect(context.collection).to eq([1, 2])
      end

      it "does not call the procedure when field has no procedure" do
        klass.preload([:author])

        field = klass.fields.find_by_name(Halitosis::CollectionPreloader::Field, :author)
        serializer = klass.new([1])
        context = Halitosis::CollectionContext.new(serializer, {})
        context.collection = [1]

        expect { serializer.send(:execute_collection_preload, context, field) }.not_to raise_error
        expect(context.collection).to eq([1])
      end
    end
  end

  describe ".default_preload" do
    it "raises InvalidField when no block is given" do
      expect { klass.default_preload }
        .to raise_error(Halitosis::InvalidField, /requires a block/)
    end

    it "raises InvalidField when called twice" do
      klass.default_preload { |coll| coll }

      expect { klass.default_preload { |coll| coll } }
        .to raise_error(Halitosis::InvalidField)
    end

    it "registers a CollectionPreloader::Field singleton" do
      klass.default_preload { |coll| coll }

      expect(klass.fields.find_by_name(Halitosis::CollectionPreloader::Field, "."))
        .to be_a(Halitosis::CollectionPreloader::Field)
    end
  end

  describe "#build_context" do
    it "applies the preload block to the collection" do
      klass.default_preload { |coll| coll.first(2) }

      ctx = klass.new(items).send(:build_context)

      expect(ctx.collection).to eq([{id: 1}, {id: 2}])
    end

    it "does not apply the preload for nested contexts" do
      klass.default_preload { |coll| coll.first(1) }

      parent_ctx = Halitosis::Context.new(nil)
      ctx = klass.new(items).send(:build_context, parent: parent_ctx)

      expect(ctx.collection).to eq(items)
    end

    it "does not modify collection when the block returns nil" do
      klass.default_preload { |_coll| nil }

      ctx = klass.new(items).send(:build_context)

      expect(ctx.collection).to eq(items)
    end

    it "runs before filtering" do
      call_order = []

      klass.default_preload do |coll|
        call_order << :preload
        coll
      end

      klass.filterable_by(:id) do |coll, value|
        call_order << :filter
        coll.select { |i| i[:id] == value.to_i }
      end

      klass.new(items).render(filter: {id: 1})

      expect(call_order).to eq(%i[preload filter])
    end

    it "runs before sorting" do
      call_order = []

      klass.default_preload do |coll|
        call_order << :preload
        coll
      end

      klass.sortable_by(:id) do |coll, ascending|
        call_order << :sort
        ascending ? coll.sort_by { |i| i[:id] } : coll.sort_by { |i| -i[:id] }
      end

      klass.new(items).render(sort: "id")

      expect(call_order).to eq(%i[preload sort])
    end
  end
end
