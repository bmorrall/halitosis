# frozen_string_literal: true

RSpec.describe Halitosis::CollectionSortable do
  let :klass do
    Class.new do
      include Halitosis

      collection :items do |items|
        items
      end

      sortable_by :name do |collection, ascending|
        ascending ? collection.sort : collection.sort.reverse
      end

      sortable_by :score do |collection, ascending|
        ascending ? collection.sort : collection.sort.reverse
      end
    end
  end

  describe ".sortable_by" do
    it "adds a Sortable::Field to the class fields" do
      fields = klass.fields.for_type(Halitosis::CollectionSortable::Field)

      expect(fields.size).to eq(2)
      expect(fields.map(&:name)).to contain_exactly(:name, :score)
    end

    it "raises InvalidField without a block" do
      expect do
        klass.sortable_by(:title)
      end.to raise_error(Halitosis::InvalidField, /sort field title must be defined with a proc/i)
    end
  end

  describe ".default_sort" do
    context "with a sort string" do
      it "registers a DefaultField" do
        klass.default_sort("name")

        expect(klass.fields.singleton(Halitosis::CollectionSortable::DefaultField)).to be_a(Halitosis::CollectionSortable::DefaultField)
      end

      it "registers a DefaultField for a descending sort string" do
        klass.default_sort("-name")

        expect(klass.fields.singleton(Halitosis::CollectionSortable::DefaultField)).to be_a(Halitosis::CollectionSortable::DefaultField)
      end
    end

    context "with a block" do
      it "registers a DefaultField" do
        klass.default_sort { collection.reverse }

        expect(klass.fields.singleton(Halitosis::CollectionSortable::DefaultField)).to be_a(Halitosis::CollectionSortable::DefaultField)
      end
    end

    context "with both a string and a block" do
      it "raises InvalidField" do
        expect do
          klass.default_sort("-name") { collection.reverse }
        end.to raise_error(Halitosis::InvalidField, /cannot specify both a string and a block/i)
      end
    end

    context "with neither string nor block" do
      it "stores no default sort field" do
        klass.default_sort

        expect(klass.fields.singleton(Halitosis::CollectionSortable::DefaultField)).to be_nil
      end
    end
  end

  describe "#apply_sorts!" do
    def build_context(serializer, options)
      serializer.send(:build_context, options)
    end

    context "with a sort param" do
      it "sorts the collection ascending" do
        serializer = klass.new(["b", "a", "c"])
        context = build_context(serializer, {sort: "name"})

        serializer.send(:apply_sorts!, context)

        expect(context.collection).to eq(["a", "b", "c"])
      end

      it "sorts the collection descending" do
        serializer = klass.new(["b", "a", "c"])
        context = build_context(serializer, {sort: "-name"})

        serializer.send(:apply_sorts!, context)

        expect(context.collection).to eq(["c", "b", "a"])
      end

      it "applies multiple sort fields in order" do
        calls = []

        multi_klass = Class.new do
          include Halitosis

          collection :items do |items|
            items
          end

          sortable_by :name do |collection, ascending|
            calls << [:name, ascending]
            collection
          end

          sortable_by :score do |collection, ascending|
            calls << [:score, ascending]
            collection
          end
        end

        serializer = multi_klass.new(["a"])
        context = build_context(serializer, {sort: "name,-score"})

        serializer.send(:apply_sorts!, context)

        expect(calls).to eq([[:name, true], [:score, false]])
      end

      it "raises InvalidQueryParameter for an unknown sort field" do
        serializer = klass.new(["a"])
        context = build_context(serializer, {sort: "unknown"})

        expect do
          serializer.send(:apply_sorts!, context)
        end.to raise_error(Halitosis::InvalidSortParameter)
      end

      it "raises InvalidSortParameter when the block returns nil for ascending" do
        nil_klass = Class.new do
          include Halitosis

          collection :items do |items|
            items
          end

          sortable_by :name do |collection, ascending|
            collection.sort if ascending
            # returns nil for descending — direction not supported
          end
        end

        serializer = nil_klass.new(["b", "a"])
        context = build_context(serializer, {sort: "-name"})

        expect do
          serializer.send(:apply_sorts!, context)
        end.to raise_error do |exception|
          expect(exception).to be_an_instance_of(Halitosis::InvalidSortParameter)
          expect(exception.message).to match(/can not be sorted by '-name'/)
          expect(exception.parameter).to eq("sort")
        end
      end

      it "raises InvalidSortParameter when the block returns nil for descending" do
        nil_klass = Class.new do
          include Halitosis

          collection :items do |items|
            items
          end

          sortable_by :name do |collection, ascending|
            collection.sort unless ascending
            # returns nil for ascending — direction not supported
          end
        end

        serializer = nil_klass.new(["b", "a"])
        context = build_context(serializer, {sort: "name"})

        expect do
          serializer.send(:apply_sorts!, context)
        end.to raise_error do |exception|
          expect(exception).to be_an_instance_of(Halitosis::InvalidSortParameter)
          expect(exception.message).to match(/can not be sorted by 'name'/)
          expect(exception.parameter).to eq("sort")
        end
      end
    end

    context "without a sort param" do
      it "is a no-op when no default is declared" do
        serializer = klass.new(["b", "a"])
        context = build_context(serializer, {})

        serializer.send(:apply_sorts!, context)

        expect(context.collection).to eq(["b", "a"])
      end

      it "applies the default_sort string via the sort pipeline" do
        klass.default_sort("name")

        serializer = klass.new(["b", "a", "c"])
        context = build_context(serializer, {})

        serializer.send(:apply_sorts!, context)

        expect(context.collection).to eq(["a", "b", "c"])
      end

      it "applies the default_sort procedure via instance_exec" do
        klass.default_sort { |collection| collection.reverse }

        serializer = klass.new(["a", "b", "c"])
        context = build_context(serializer, {})

        serializer.send(:apply_sorts!, context)

        expect(context.collection).to eq(["c", "b", "a"])
      end
    end

    context "with an explicit nil sort param" do
      it "is a no-op when no default is declared" do
        serializer = klass.new(["b", "a"])
        context = build_context(serializer, {sort: nil})

        serializer.send(:apply_sorts!, context)

        expect(context.collection).to eq(["b", "a"])
      end
    end
  end
end
