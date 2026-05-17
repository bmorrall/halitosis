# frozen_string_literal: true

RSpec.describe Halitosis::Sortable::Field do
  describe "#validate" do
    it "raises InvalidField when no procedure is given" do
      field = described_class.new(:name, {}, nil)

      expect { field.validate }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidField)
        expect(exception.message).to match(/sort field name must be defined with a proc/i)
      end
    end

    it "returns true when a procedure is given" do
      field = described_class.new(:name, {}, proc { |asc| })

      expect(field.validate).to be true
    end

    it "raises InvalidField for a value option without a procedure" do
      field = described_class.new(:name, {value: "foo"}, nil)

      expect { field.validate }.to raise_error(Halitosis::InvalidField)
    end

    it "raises InvalidField when both value and procedure are given" do
      field = described_class.new(:name, {value: "foo"}, proc { |asc| })

      expect { field.validate }.to raise_error(Halitosis::InvalidField)
    end
  end

  describe "#apply_sort" do
    it "calls instance_exec on the instance with the ascending flag" do
      received_ascending = nil

      field = described_class.new(:name, {}, proc { |asc|
        received_ascending = asc
        "sorted_result"
      })

      context = Halitosis::Context.new(Object.new)
      result = field.apply_sort(context, true)

      expect(received_ascending).to be true
      expect(result).to eq("sorted_result")
    end

    it "passes false for descending" do
      received_ascending = nil

      field = described_class.new(:name, {}, proc { |asc| received_ascending = asc })
      field.apply_sort(Halitosis::Context.new(Object.new), false)

      expect(received_ascending).to be false
    end

    it "evaluates the block in the instance scope" do
      instance = Class.new do
        def collection
          [3, 1, 2]
        end
      end.new

      field = described_class.new(:name, {}, proc { |asc|
        asc ? collection.sort : collection.sort.reverse
      })

      expect(field.apply_sort(Halitosis::Context.new(instance), true)).to eq([1, 2, 3])
      expect(field.apply_sort(Halitosis::Context.new(instance), false)).to eq([3, 2, 1])
    end
  end
end
