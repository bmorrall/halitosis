# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPreload do
  let(:items) { [{id: 1}, {id: 2}, {id: 3}] }

  let(:klass) do
    Class.new do
      include Halitosis

      collection :items do |items|
        items
      end
    end
  end

  describe ".preload_collection" do
    it "raises InvalidField when no block is given" do
      expect { klass.preload_collection }
        .to raise_error(Halitosis::InvalidField, /requires a block/)
    end

    it "raises InvalidField when called twice" do
      klass.preload_collection { |coll| coll }

      expect { klass.preload_collection { |coll| coll } }
        .to raise_error(Halitosis::InvalidField)
    end

    it "registers a CollectionPreload::Field singleton" do
      klass.preload_collection { |coll| coll }

      expect(klass.fields.singleton(Halitosis::CollectionPreload::Field))
        .to be_a(Halitosis::CollectionPreload::Field)
    end
  end

  describe "#build_context" do
    it "applies the preload block to the collection" do
      klass.preload_collection { |coll| coll.first(2) }

      ctx = klass.new(items).send(:build_context)

      expect(ctx.collection).to eq([{id: 1}, {id: 2}])
    end

    it "does not apply the preload for nested contexts" do
      klass.preload_collection { |coll| coll.first(1) }

      parent_ctx = Halitosis::Context.new(nil)
      ctx = klass.new(items).send(:build_context, parent: parent_ctx)

      expect(ctx.collection).to eq(items)
    end

    it "does not modify collection when the block returns nil" do
      klass.preload_collection { |_coll| nil }

      ctx = klass.new(items).send(:build_context)

      expect(ctx.collection).to eq(items)
    end

    it "runs before filtering" do
      call_order = []

      klass.preload_collection do |coll|
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

      klass.preload_collection do |coll|
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
