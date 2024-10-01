# frozen_string_literal: true

RSpec.describe Halitosis::Permissions do
  let :klass do
    Class.new { include Halitosis }
  end

  describe Halitosis::Permissions::ClassMethods do
    describe "#permission" do
      it "defines permission" do
        expect do
          klass.permission(:foo)
        end.to change(klass.fields, :size).by(1)
      end
    end
  end

  describe Halitosis::Permissions::InstanceMethods do
    let :serializer do
      klass.new
    end

    describe "#render" do
      it "merges super with rendered permission" do
        allow(serializer).to receive(:permissions).and_return(foo: "bar")

        expect(serializer.render).to eq(_permissions: {foo: "bar"})
      end

      it "renders permissions with true values" do
        klass.permission(:foo, value: true)

        expect(serializer.render).to eq(_permissions: {foo: true})
      end

      it "renders permissions with false values" do
        klass.permission(:foo, value: false)

        expect(serializer.render).to eq(_permissions: {foo: false})
      end

      it "excludes permissions with nil values as false" do
        klass.permission(:foo, value: nil)

        expect(serializer.render).to eq(_permissions: {foo: false})
      end
    end

    describe "#permissions" do
      it "builds permission from fields" do
        klass.permission(:foo, value: "bar")

        expect(serializer.permissions).to eq(foo: "bar")
      end
    end
  end
end
