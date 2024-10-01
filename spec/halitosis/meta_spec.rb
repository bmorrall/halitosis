# frozen_string_literal: true

RSpec.describe Halitosis::Meta do
  let :klass do
    Class.new { include Halitosis }
  end

  describe Halitosis::Meta::ClassMethods do
    describe "#meta" do
      it "defines meta" do
        expect do
          klass.meta(:foo)
        end.to change(klass.fields, :size).by(1)
      end
    end
  end

  describe Halitosis::Meta::InstanceMethods do
    let :serializer do
      klass.new
    end

    describe "#render" do
      it "merges super with rendered meta" do
        allow(serializer).to receive(:meta).and_return(foo: "bar")

        expect(serializer.render).to eq(_meta: {foo: "bar"})
      end

      it "renders meta with string values" do
        klass.meta(:foo, value: "bar")

        expect(serializer.render).to eq(_meta: {foo: "bar"})
      end

      it "renders meta with integer values" do
        klass.meta(:foo, value: 1)

        expect(serializer.render).to eq(_meta: {foo: 1})
      end

      it "renders meta with true values" do
        klass.meta(:foo, value: true)

        expect(serializer.render).to eq(_meta: {foo: true})
      end

      it "renders meta with false values" do
        klass.meta(:foo, value: false)

        expect(serializer.render).to eq(_meta: {foo: false})
      end
    end

    describe "#meta" do
      it "builds meta from fields" do
        klass.meta(:foo, value: "bar")

        expect(serializer.meta).to eq(foo: "bar")
      end
    end
  end
end
