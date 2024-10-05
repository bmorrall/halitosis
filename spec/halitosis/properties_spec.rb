# frozen_string_literal: true

RSpec.describe Halitosis::Properties do
  let :klass do
    Class.new { include Halitosis }
  end

  describe Halitosis::Properties::ClassMethods do
    describe "#attribute" do
      it "defines a property field" do
        expect do
          klass.attribute(:foo)
        end.to change(klass.fields, :size).by(1)

        inserted_field = klass.fields[Halitosis::Properties::Field.name].last
        expect(inserted_field).to be_a(Halitosis::Properties::Field)
        expect(inserted_field.name).to eq(:foo)
      end
    end

    describe "#property" do
      it "defines a property field" do
        expect do
          klass.property(:bar)
        end.to change(klass.fields, :size).by(1)

        inserted_field = klass.fields[Halitosis::Properties::Field.name].last
        expect(inserted_field).to be_a(Halitosis::Properties::Field)
        expect(inserted_field.name).to eq(:bar)
      end
    end
  end

  describe Halitosis::Properties::InstanceMethods do
    let :serializer do
      klass.new
    end

    describe "#render" do
      it "merges super with rendered properties" do
        allow(serializer).to receive(:properties).and_return(foo: "bar")

        expect(serializer.render).to eq(foo: "bar")
      end
    end

    describe "#properties" do
      it "builds properties from fields" do
        klass.attribute(:foo, value: "bar")

        expect(serializer.properties).to eq(foo: "bar")
      end
    end
  end
end
