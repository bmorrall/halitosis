# frozen_string_literal: true

RSpec.describe Halitosis::Sortable do
  let :klass do
    Class.new do
      include Halitosis

      collection :items do
        collection
      end

      sortable_by :name do |ascending|
        ascending ? collection.sort : collection.sort.reverse
      end

      sortable_by :score do |ascending|
        ascending ? collection.sort : collection.sort.reverse
      end
    end
  end

  describe ".sortable_by" do
    it "adds a Sortable::Field to the class fields" do
      fields = klass.fields.for_type(Halitosis::Sortable::Field)

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
      it "stores the default sort string" do
        klass.default_sort("name")

        expect(klass.default_sort_string).to eq("name")
      end

      it "stores a descending sort string" do
        klass.default_sort("-name")

        expect(klass.default_sort_string).to eq("-name")
      end
    end

    context "with a block" do
      it "stores the default sort procedure" do
        the_proc = proc { collection.reverse }
        klass.default_sort(&the_proc)

        expect(klass.default_sort_procedure).to eq(the_proc)
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
      it "stores nothing" do
        klass.default_sort

        expect(klass.default_sort_string).to be_nil
        expect(klass.default_sort_procedure).to be_nil
      end
    end
  end

  describe "#validate_sorts!" do
    let(:serializer) { klass.new(["b", "a"]) }

    it "passes when all requested fields are declared" do
      expect do
        serializer.send(:validate_sorts!, [["name", true]])
      end.not_to raise_error
    end

    it "passes for multiple known fields" do
      expect do
        serializer.send(:validate_sorts!, [["name", true], ["score", false]])
      end.not_to raise_error
    end

    it "raises InvalidQueryParameter for an unknown field" do
      expect do
        serializer.send(:validate_sorts!, [["unknown", true]])
      end.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidQueryParameter)
        expect(exception.message).to match(/can not be sorted by 'unknown'/i)
        expect(exception.parameter).to eq("sort")
      end
    end

    it "reports the first unknown field" do
      expect do
        serializer.send(:validate_sorts!, [["name", true], ["bogus", false]])
      end.to raise_error(Halitosis::InvalidQueryParameter, /can not be sorted by 'bogus'/)
    end

    it "includes the resource type in the error message" do
      expect do
        serializer.send(:validate_sorts!, [["nope", true]])
      end.to raise_error(Halitosis::InvalidQueryParameter, /items collection/)
    end
  end

  describe "#apply_sorts!" do
    def build_context(serializer, options)
      Halitosis::Context.new(serializer, options)
    end

    context "with a sort param" do
      it "sorts the collection ascending" do
        serializer = klass.new(["b", "a", "c"])
        context = build_context(serializer, {sort: "name"})

        serializer.send(:apply_sorts!, context)

        expect(serializer.collection).to eq(["a", "b", "c"])
      end

      it "sorts the collection descending" do
        serializer = klass.new(["b", "a", "c"])
        context = build_context(serializer, {sort: "-name"})

        serializer.send(:apply_sorts!, context)

        expect(serializer.collection).to eq(["c", "b", "a"])
      end

      it "applies multiple sort fields in order" do
        calls = []

        multi_klass = Class.new do
          include Halitosis

          collection :items do
            collection
          end

          sortable_by :name do |ascending|
            calls << [:name, ascending]
            collection
          end

          sortable_by :score do |ascending|
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
        end.to raise_error(Halitosis::InvalidQueryParameter)
      end
    end

    context "without a sort param" do
      it "is a no-op when no default is declared" do
        serializer = klass.new(["b", "a"])
        context = build_context(serializer, {})

        serializer.send(:apply_sorts!, context)

        expect(serializer.collection).to eq(["b", "a"])
      end

      it "applies the default_sort string via the sort pipeline" do
        klass.default_sort("name")

        serializer = klass.new(["b", "a", "c"])
        context = build_context(serializer, {})

        serializer.send(:apply_sorts!, context)

        expect(serializer.collection).to eq(["a", "b", "c"])
      end

      it "applies the default_sort procedure via instance_exec" do
        klass.default_sort { collection.reverse }

        serializer = klass.new(["a", "b", "c"])
        context = build_context(serializer, {})

        serializer.send(:apply_sorts!, context)

        expect(serializer.collection).to eq(["c", "b", "a"])
      end
    end

    context "with an explicit nil sort param" do
      it "is a no-op when no default is declared" do
        serializer = klass.new(["b", "a"])
        context = build_context(serializer, {sort: nil})

        serializer.send(:apply_sorts!, context)

        expect(serializer.collection).to eq(["b", "a"])
      end
    end
  end
end
