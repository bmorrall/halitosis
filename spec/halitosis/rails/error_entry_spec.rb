# frozen_string_literal: true

return unless defined?(Rails)

RSpec.describe Halitosis::ErrorEntry, :rails do
  let(:exception) { StandardError.new("Something went wrong") }

  it "raises MissingOption when error is not provided" do
    expect { described_class.new }.to raise_error(Halitosis::MissingOption)
  end

  it "renders an empty hash when no fields are defined" do
    result = described_class.new(error: exception).as_json

    expect(result).to eq({})
  end

  it "does not support identifier" do
    expect { described_class.identifier(:id) }.to raise_error(NoMethodError)
  end

  it "does not support permission" do
    expect { described_class.permission(:read) { true } }.to raise_error(NoMethodError)
  end

  it "does not support relationship" do
    expect { described_class.relationship(:author) { nil } }.to raise_error(NoMethodError)
  end

  describe "ClassMethods" do
    subject(:entry_class) { Class.new(described_class) }

    %i[id code title status detail].each do |field|
      describe "##{field}" do
        it "defines a #{field} attribute" do
          entry_class.public_send(field) { field.to_s.upcase }

          result = entry_class.new(error: exception).as_json

          expect(result[field.to_s]).to eq(field.to_s.upcase)
        end
      end
    end

    describe "#source_pointer" do
      it "renders source with pointer key" do
        entry_class.source_pointer { "/data/attributes/title" }

        result = entry_class.new(error: exception).as_json

        expect(result["source"]).to eq("pointer" => "/data/attributes/title")
      end
    end

    describe "#source_parameter" do
      it "renders source with parameter key" do
        entry_class.source_parameter { "sort" }

        result = entry_class.new(error: exception).as_json

        expect(result["source"]).to eq("parameter" => "sort")
      end
    end

    describe "#source_header" do
      it "renders source with header key" do
        entry_class.source_header { "Authorization" }

        result = entry_class.new(error: exception).as_json

        expect(result["source"]).to eq("header" => "Authorization")
      end
    end

    it "exposes the exception as `error` in attribute blocks" do
      entry_class.detail { error.message }

      result = entry_class.new(error: exception).as_json

      expect(result["detail"]).to eq("Something went wrong")
    end
  end
end
