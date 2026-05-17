# frozen_string_literal: true

RSpec.describe Halitosis::CollectionFilterable::Namespace do
  subject(:namespace) { described_class.new("user", target_class) }

  let(:target_class) do
    Class.new do
      include Halitosis

      collection :items do
        collection
      end
    end
  end

  describe "#filterable_by" do
    context "with a 2-arity block (field)" do
      it "registers a dot-prefixed Filterable::Field on the target class" do
        namespace.filterable_by(:name) { |col, v| col }

        fields = target_class.fields.for_type(Halitosis::CollectionFilterable::Field)
        expect(fields.size).to eq(1)
        expect(fields.first.name).to eq(:"user.name")
      end

      it "passes options through to the field" do
        namespace.filterable_by(:name, if: :admin?) { |col, v| col }

        field = target_class.fields.for_type(Halitosis::CollectionFilterable::Field).first
        expect(field.options[:if]).to eq(:admin?)
      end
    end

    context "with a 0-arity block (nested namespace)" do
      it "recurses and registers the deeply prefixed field" do
        namespace.filterable_by(:address) do
          filterable_by(:city) { |col, v| col }
        end

        fields = target_class.fields.for_type(Halitosis::CollectionFilterable::Field)
        expect(fields.size).to eq(1)
        expect(fields.first.name).to eq(:"user.address.city")
      end
    end

    context "without a block" do
      it "raises InvalidField" do
        expect do
          namespace.filterable_by(:name)
        end.to raise_error(Halitosis::InvalidField, /must be defined with a proc/i)
      end
    end

    context "with a block that accepts more than 2 arguments" do
      it "raises InvalidField" do
        expect do
          namespace.filterable_by(:name) { |a, b, c| a }
        end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*or 2 arguments/i)
      end
    end
  end
end
