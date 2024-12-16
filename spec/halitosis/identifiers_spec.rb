# frozen_string_literal: true

RSpec.describe Halitosis::Identifiers do
  let :klass do
    Class.new {
      include Halitosis::Base
      include Halitosis::Identifiers
    }
  end

  describe Halitosis::Identifiers::ClassMethods do
    describe "#identifier" do
      it "defines an identifier field" do
        expect do
          klass.identifier(:foo)
        end.to change(klass.fields, :size).by(1)

        inserted_field = klass.fields.for_type(Halitosis::Identifiers::Field).last
        expect(inserted_field).to be_a(Halitosis::Identifiers::Field)
        expect(inserted_field.name).to eq(:foo)
      end

      it "raises an error when multiple identifiers are defined" do
        klass.identifier(:foo)

        expect do
          klass.identifier(:bar)
        end.to raise_error(Halitosis::InvalidField, "You can only define one identifier per serializer")
      end
    end
  end

  describe Halitosis::Identifiers::InstanceMethods do
    let :serializer do
      klass.new
    end

    describe "#render" do
      it "merges super with rendered identifiers" do
        allow(serializer).to receive(:identifiers).and_return(foo: "bar")

        expect(serializer.render).to eq(foo: "bar")
      end
    end

    describe "#to_json" do
      it "renders the JSON representation with inline identifiers" do
        klass.identifier(:foo, value: "bar")

        expect(serializer.to_json).to eq('{"foo":"bar"}')
      end
    end

    describe "#identifiers" do
      it "builds identifiers from fields" do
        klass.identifier(:foo, value: "bar")

        expect(serializer.identifiers).to eq(foo: "bar")
      end
    end
  end
end
