# frozen_string_literal: true

RSpec.describe Halitosis::Filterable::Field do
  describe "#validate" do
    it "raises InvalidField when no procedure is given" do
      field = described_class.new(:name, {}, nil)

      expect { field.validate }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidField)
        expect(exception.message).to match(/filter field name must be defined with a proc/i)
      end
    end

    it "returns true when a procedure is given" do
      field = described_class.new(:name, {}, proc { |v| v })

      expect(field.validate).to be true
    end

    it "raises InvalidField for a value option without a procedure" do
      field = described_class.new(:name, {value: "foo"}, nil)

      expect { field.validate }.to raise_error(Halitosis::InvalidField)
    end

    it "raises InvalidField when both value and procedure are given" do
      field = described_class.new(:name, {value: "foo"}, proc { |v| v })

      expect { field.validate }.to raise_error(Halitosis::InvalidField)
    end
  end

  describe "#apply_filter" do
    it "calls instance_exec on the instance with the value" do
      received_value = nil
      field = described_class.new(:name, {}, proc { |v|
        received_value = v
        "filtered_result"
      })

      context = Halitosis::Context.new(Object.new)
      result = field.apply_filter(context, "Alice")

      expect(received_value).to eq("Alice")
      expect(result).to eq("filtered_result")
    end

    it "evaluates the block in the instance scope" do
      instance = Class.new do
        def collection = [1, 2, 3, 4, 5]
      end.new

      field = described_class.new(:min, {}, proc { |v|
        collection.select { |i| i >= v.to_i }
      })

      expect(field.apply_filter(Halitosis::Context.new(instance), "3")).to eq([3, 4, 5])
    end

    it "returns nil when the block returns nil" do
      field = described_class.new(:score, {}, proc { |_v| })

      expect(field.apply_filter(Halitosis::Context.new(Object.new), "bad")).to be_nil
    end
  end
end
