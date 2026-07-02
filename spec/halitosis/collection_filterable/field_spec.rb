# frozen_string_literal: true

RSpec.describe Halitosis::CollectionFilterable::Field do
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
    it "passes collection and value to the proc" do
      received = []
      field = described_class.new(:name, {}, proc { |col, v|
        received = [col, v]
        "filtered_result"
      })

      context = Halitosis::Context.new(Object.new)
      result, errors = field.apply_filter(context, [1, 2, 3], "Alice")

      expect(received).to eq([[1, 2, 3], "Alice"])
      expect(result).to eq("filtered_result")
      expect(errors).to be_nil
    end

    it "evaluates the block in the instance scope" do
      instance = Class.new.new

      field = described_class.new(:min, {}, proc { |col, v|
        col.select { |i| i >= v.to_i }
      })

      result, = field.apply_filter(Halitosis::Context.new(instance), [1, 2, 3, 4, 5], "3")
      expect(result).to eq([3, 4, 5])
    end

    it "returns nil when the block returns nil" do
      field = described_class.new(:score, {}, proc { |_col, _v| })

      result, = field.apply_filter(Halitosis::Context.new(Object.new), [], "bad")
      expect(result).to be_nil
    end

    context "when the block raises InvalidFilterParameter" do
      it "re-raises with the field name when no field name was given" do
        field = described_class.new(:status, {}, proc { |_col, _v|
          raise Halitosis::InvalidFilterParameter.new("Invalid status value")
        })

        expect { field.apply_filter(Halitosis::Context.new(Object.new), [], "bad") }
          .to raise_error(Halitosis::InvalidFilterParameter) do |e|
            expect(e.message).to eq("Invalid status value")
            expect(e.parameter).to eq("filter[status]")
          end
      end

      it "preserves the original exception when a specific field name was already set" do
        field = described_class.new(:status, {}, proc { |_col, _v|
          raise Halitosis::InvalidFilterParameter.new("Invalid sub-field", "status.code")
        })

        expect { field.apply_filter(Halitosis::Context.new(Object.new), [], "bad") }
          .to raise_error(Halitosis::InvalidFilterParameter) do |e|
            expect(e.parameter).to eq("filter[status][code]")
          end
      end
    end

    context "with a 3-argument block (collection, value, errors)" do
      it "yields a FilterErrors object initialized with the field name" do
        received_errors = nil
        field = described_class.new(:status, {}, proc { |col, v, errors|
          received_errors = errors
          col
        })

        field.apply_filter(Halitosis::Context.new(Object.new), [], "x")
        expect(received_errors).to be_a(Halitosis::FilterErrors)
        expect(received_errors.field_name).to eq("status")
      end

      it "returns the FilterErrors object alongside the result" do
        field = described_class.new(:status, {}, proc { |col, v, errors|
          errors.add("is invalid")
          nil
        })

        result, errors = field.apply_filter(Halitosis::Context.new(Object.new), [], "bad")
        expect(result).to be_nil
        expect(errors).to be_a(Halitosis::FilterErrors)
        expect(errors).to be_any
        expect(errors.first).to eq(["status", ["is invalid"]])
        expect(errors.to_h).to eq({"status" => ["is invalid"]})
      end

      it "respects a field name override in add" do
        field = described_class.new(:"account.date_range", {}, proc { |col, v, errors|
          errors.add("started_at", "is not a valid date")
          nil
        })

        _, errors = field.apply_filter(Halitosis::Context.new(Object.new), [], "bad")
        expect(errors.to_h).to eq({"account.started_at" => ["is not a valid date"]})
      end
    end
  end

  describe "#compound?" do
    it "returns false when no keys option is given" do
      field = described_class.new(:name, {}, proc { |c, v| c })

      expect(field.compound?).to be false
    end

    it "returns true when a keys option is given" do
      field = described_class.new(:start_date, {keys: [:from, :to]}, proc { |c, v| c })

      expect(field.compound?).to be true
    end
  end

  describe "#compound_keys" do
    it "returns an empty array when no keys option is given" do
      field = described_class.new(:name, {}, proc { |c, v| c })

      expect(field.compound_keys).to eq([])
    end

    it "returns symbolized keys" do
      field = described_class.new(:start_date, {keys: ["from", :to]}, proc { |c, v| c })

      expect(field.compound_keys).to eq([:from, :to])
    end
  end

  describe "#validate — keys option" do
    it "raises InvalidField when keys is an empty array" do
      field = described_class.new(:start_date, {keys: []}, proc { |c, v| c })

      expect { field.validate }.to raise_error(Halitosis::InvalidField, /keys option must be a non-empty array/i)
    end

    it "raises InvalidField when keys contains non-symbol/string values" do
      field = described_class.new(:start_date, {keys: [1, 2]}, proc { |c, v| c })

      expect { field.validate }.to raise_error(Halitosis::InvalidField, /keys option must be a non-empty array/i)
    end

    it "does not raise when keys is a valid non-empty array of symbols" do
      field = described_class.new(:start_date, {keys: [:from, :to]}, proc { |c, v| c })

      expect { field.validate }.not_to raise_error
    end

    it "does not raise when keys contains strings" do
      field = described_class.new(:start_date, {keys: ["from", "to"]}, proc { |c, v| c })

      expect { field.validate }.not_to raise_error
    end
  end

  describe "#apply_filter — compound field" do
    it "passes the hash value to a 2-argument block" do
      received = nil
      field = described_class.new(:start_date, {keys: [:from, :to]}, proc { |col, value|
        received = value
        col
      })

      field.apply_filter(Halitosis::Context.new(Object.new), [], {from: "2024-01-01", to: "2024-12-31"})
      expect(received).to eq({from: "2024-01-01", to: "2024-12-31"})
    end

    context "with a 3-argument block" do
      it "initializes FilterErrors with the field name as prefix" do
        received_errors = nil
        field = described_class.new(:start_date, {keys: [:from, :to]}, proc { |col, value, errors|
          received_errors = errors
          col
        })

        field.apply_filter(Halitosis::Context.new(Object.new), [], {from: "2024-01-01", to: "2024-12-31"})
        expect(received_errors.field_name).to eq("start_date")
      end

      it "resolves errors.add(sub_key, message) under the compound field name" do
        field = described_class.new(:start_date, {keys: [:from, :to]}, proc { |col, value, errors|
          errors.add("from", "is required")
          nil
        })

        _, errors = field.apply_filter(Halitosis::Context.new(Object.new), [], {to: "2024-12-31"})
        expect(errors.to_h).to eq({"start_date.from" => ["is required"]})
      end

      it "resolves errors.add(message) under the compound field name itself" do
        field = described_class.new(:start_date, {keys: [:from, :to]}, proc { |col, value, errors|
          errors.add("range is invalid")
          nil
        })

        _, errors = field.apply_filter(Halitosis::Context.new(Object.new), [], {from: "2024-12-31", to: "2024-01-01"})
        expect(errors.to_h).to eq({"start_date" => ["range is invalid"]})
      end

      it "resolves sub-key errors under a namespaced compound field" do
        field = described_class.new(:"item.start_date", {keys: [:from, :to]}, proc { |col, value, errors|
          errors.add("from", "is required")
          nil
        })

        _, errors = field.apply_filter(Halitosis::Context.new(Object.new), [], {to: "2024-12-31"})
        expect(errors.to_h).to eq({"item.start_date.from" => ["is required"]})
      end
    end
  end
end
