# frozen_string_literal: true

RSpec.describe Halitosis::Base do
  let :resource_serializer do
    Class.new do
      include Halitosis::Base
    end
  end

  describe Halitosis::Base::InstanceMethods do
    describe "#initialize" do
      it "symbolizes option keys" do
        serializer = resource_serializer.new(
          "include" => {"foo" => "bar"},
          "ignore" => "this",
          :convert => "that"
        )

        expect(serializer.options).to eq(
          include: {foo: "bar"},
          ignore: "this",
          convert: "that"
        )
      end
    end

    describe Halitosis::Base::ClassMethods do
      describe ".required_option" do
        it "defines a reader method backed by options" do
          klass = Class.new { include Halitosis::Base }
          klass.required_option :current_user

          serializer = klass.new(current_user: "alice")

          expect(serializer.current_user).to eq("alice")
        end

        it "raises MissingOption when the option is absent" do
          klass = Class.new { include Halitosis::Base }
          klass.required_option :current_user

          expect { klass.new }.to raise_error(Halitosis::MissingOption, /current_user/)
        end

        it "inherits required_option_keys from superclass" do
          parent = Class.new { include Halitosis::Base }
          parent.required_option :tenant

          child = Class.new(parent)

          expect(child.required_option_keys).to include(:tenant)
        end

        it "does not share required_option_keys across siblings" do
          base = Class.new { include Halitosis::Base }
          Class.new(base) { required_option :foo }
          b = Class.new(base)

          expect(b.required_option_keys).not_to include(:foo)
        end
      end
    end

    describe "#render_child" do
      let :klass do
        Class.new { include Halitosis::Base }
      end

      it "returns nil if child is not a serializer" do
        serializer = klass.new
        context = serializer.send(:build_context)

        [nil, 1, ""].each do |child|
          expect(resource_serializer.new.send(:render_child, child, context, {})).to be_nil
        end
      end

      it "renders child serializer with correct parent and options" do
        serializer = klass.new
        context = serializer.send(:build_context)
        captured = nil
        serializer.define_singleton_method(:render_with_context) { |ctx|
          captured = ctx
          {}
        }

        serializer.send(:render_child, serializer, context, foo: "bar")

        expect(captured.parent.object_id).to eq(context.object_id)
        expect(captured.fetch(:include)).to eq(foo: "bar")
      end

      it "merges child options if already present" do
        serializer = klass.new(include: {bar: "bar"})
        context = serializer.send(:build_context)
        captured = nil
        serializer.define_singleton_method(:render_with_context) { |ctx|
          captured = ctx
          {}
        }

        serializer.send(:render_child, serializer, context, foo: "foo")

        expect(captured.fetch(:include)).to eq(foo: "foo", bar: "bar")
      end

      it "calls before_render on the child before rendering" do
        before_render_called = false

        child_klass = Class.new do
          include Halitosis::Base

          define_method(:before_render) { |_ctx| before_render_called = true }
        end

        serializer = klass.new
        context = serializer.send(:build_context)

        serializer.send(:render_child, child_klass.new, context, {})

        expect(before_render_called).to be true
      end
    end

    describe "#as_json", :rails do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new.as_json).to eq({})
      end
    end

    describe "#to_json" do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new.to_json).to eq("{}")
      end
    end

    describe "#before_render" do
      it "is called during render" do
        call_count = 0
        resource_serializer.define_method(:before_render) { |_ctx| call_count += 1 }

        resource_serializer.new.render

        expect(call_count).to eq(1)
      end

      it "receives the built context" do
        received_context = nil
        resource_serializer.define_method(:before_render) { |ctx| received_context = ctx }

        serializer = resource_serializer.new
        serializer.render

        expect(received_context).to be_a(Halitosis::Context)
      end
    end

    describe "#to_xml", skip: "XML output not yet implemented" do
      it "converts rendered serializer to json" do
        expect(resource_serializer.new.to_xml).to eq(
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n</hash>\n"
        )
      end
    end
  end
end
