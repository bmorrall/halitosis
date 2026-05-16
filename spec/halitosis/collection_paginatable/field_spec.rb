# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::Field do
  describe "#validate" do
    it "raises InvalidField when no procedure is set" do
      field = described_class.new(:pagination, {}, nil)

      expect { field.validate }
        .to raise_error(Halitosis::InvalidField, /must be defined with a proc/i)
    end
  end
end
