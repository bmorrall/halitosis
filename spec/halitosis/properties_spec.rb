# frozen_string_literal: true

RSpec.describe Halitosis::Properties do
  let :klass do
    Class.new { include Halitosis }
  end

  describe Halitosis::Properties::ClassMethods do
    describe "#property" do
      it "defines property" do
        expect do
          klass.property(:foo)
        end.to change(klass.fields, :size).by(1)
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
        klass.property(:foo, value: "bar")

        expect(serializer.properties).to eq(foo: "bar")
      end
    end
  end
end
