# frozen_string_literal: true

RSpec.describe Halitosis::Attributes do
  let :klass do
    Class.new {
      include Halitosis::Base
      include Halitosis::Attributes
    }
  end

  describe Halitosis::Attributes::ClassMethods do
    describe "#attribute" do
      it "defines an attribute field" do
        expect do
          klass.attribute(:foo)
        end.to change(klass.fields, :size).by(1)

        inserted_field = klass.fields[Halitosis::Attributes::Field.name].last
        expect(inserted_field).to be_a(Halitosis::Attributes::Field)
        expect(inserted_field.name).to eq(:foo)
      end
    end

    describe "#property" do
      it "defines a attribute field" do
        expect do
          klass.property(:bar)
        end.to change(klass.fields, :size).by(1)

        inserted_field = klass.fields[Halitosis::Attributes::Field.name].last
        expect(inserted_field).to be_a(Halitosis::Attributes::Field)
        expect(inserted_field.name).to eq(:bar)
      end
    end
  end

  describe Halitosis::Attributes::InstanceMethods do
    let :serializer do
      klass.new
    end

    describe "#render" do
      it "merges super with rendered attributes" do
        allow(serializer).to receive(:attributes).and_return(foo: "bar")

        expect(serializer.render).to eq(foo: "bar")
      end
    end

    describe "#to_json" do
      it "renders the JSON representation with inline attributes" do
        klass.attribute(:foo, value: "bar")

        expect(serializer.to_json).to eq('{"foo":"bar"}')
      end
    end

    describe "#attributes" do
      it "builds attributes from fields" do
        klass.attribute(:foo, value: "bar")

        expect(serializer.attributes).to eq(foo: "bar")
      end
    end
  end
end
