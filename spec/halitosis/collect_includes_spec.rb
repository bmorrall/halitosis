# frozen_string_literal: true

RSpec.describe Halitosis::CollectIncludes do
  let :child_klass do
    Class.new do
      include Halitosis
      include Halitosis::ResourceRelationships

      identifier :id, value: 42
      attribute(:name) { "child" }

      define_singleton_method(:resource_type) { "child" }
    end
  end

  let :klass do
    child_klass = self.child_klass

    Class.new do
      include Halitosis
      include Halitosis::ResourceRelationships

      collect_includes!

      relationship :child do
        child_klass.new
      end
    end
  end

  describe ".collect_includes!" do
    it "includes CollectIncludes::InstanceMethods" do
      expect(klass.ancestors).to include(Halitosis::CollectIncludes::InstanceMethods)
    end

    context "when config.collect_includes is true" do
      before { allow(Halitosis.config).to receive(:collect_includes).and_return(true) }

      it "automatically includes CollectIncludes::InstanceMethods without calling collect_includes!" do
        child_klass = self.child_klass

        klass = Class.new do
          include Halitosis
          include Halitosis::ResourceRelationships

          relationship :child do
            child_klass.new
          end
        end

        result = klass.new(include: {child: true}).render

        expect(klass.ancestors).to include(Halitosis::CollectIncludes::InstanceMethods)
        expect(result[:_relationships][:child]).to eq(id: 42, _type: "child")
        expect(result[:included]).to eq(child: [{id: 42, name: "child"}])
      end
    end
  end

  describe Halitosis::CollectIncludes::InstanceMethods do
    describe "#render" do
      context "when no relationships are included" do
        it "does not add an included key" do
          serializer = klass.new

          result = serializer.render
          expect(result).not_to have_key(:included)
        end
      end

      context "when a relationship is included but returns nil" do
        it "renders an empty included hash" do
          klass = Class.new do
            include Halitosis
            include Halitosis::ResourceRelationships

            collect_includes!

            relationship :child do
              nil
            end
          end

          result = klass.new(include: {child: true}).render

          expect(result[:_relationships][:child]).to be_nil
          expect(result[:included]).to eq({})
        end
      end

      context "when a relationship is included" do
        it "stubs the relationship and adds the full payload to included" do
          serializer = klass.new(include: {child: true})

          result = serializer.render
          expect(result[:_relationships][:child]).to eq(id: 42, _type: "child")
          expect(result[:included]).to eq(child: [{id: 42, name: "child"}])
        end
      end
    end

    describe "#render_child" do
      let(:context_without_registry) do
        Halitosis::Context.new(klass.new, {})
      end

      it "falls back to super when child is not a Halitosis::Base instance" do
        plain_child = Object.new
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {}

        result = serializer.send(:render_child, plain_child, context, {})
        expect(result).to be_nil
      end

      it "falls back to super when no included_registry on context" do
        serializer = klass.new
        child = child_klass.new
        opts = {}

        result = serializer.send(:render_child, child, context_without_registry, opts)
        expect(result).to eq(id: 42, name: "child")
      end

      it "falls back to super when child has no Identifiers::Field" do
        no_id_klass = Class.new do
          include Halitosis

          attribute(:name) { "no id" }
        end

        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {}
        child = no_id_klass.new

        result = serializer.send(:render_child, child, context, {})
        expect(result).to eq(name: "no id")
        expect(context.included_registry).to be_empty
      end

      it "stores the full payload in the registry and returns a stub" do
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {}
        child = child_klass.new

        result = serializer.send(:render_child, child, context, {})
        expect(result).to eq(id: 42, _type: "child")
        expect(context.included_registry).to eq(["child", 42] => {id: 42, name: "child"})
      end

      it "does not re-render a child already in the registry" do
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {["child", 42] => {id: 42, name: "existing"}}
        child = child_klass.new

        expect(child).not_to receive(:render_with_context)
        result = serializer.send(:render_child, child, context, {})

        expect(result).to eq(id: 42, _type: "child")
        expect(context.included_registry[["child", 42]][:name]).to eq("existing")
      end

      it "extends child instances with InstanceMethods for recursive stubbing" do
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {}
        child = child_klass.new

        serializer.send(:render_child, child, context, {})
        expect(child).to be_a(Halitosis::CollectIncludes::InstanceMethods) # rubocop:disable RSpec/DescribedClass
      end

      it "does not re-extend a child already extended with InstanceMethods" do
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {}
        child = child_klass.new
        child.extend(Halitosis::CollectIncludes::InstanceMethods) # rubocop:disable RSpec/DescribedClass

        # child is already extended — must not call extend again
        expect(child).not_to receive(:extend)
        serializer.send(:render_child, child, context, {})
      end

      it "calls before_render on the child before rendering into the registry" do
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {}
        child = child_klass.new
        before_render_called = false

        child.define_singleton_method(:before_render) { |_ctx| before_render_called = true }

        serializer.send(:render_child, child, context, {})

        expect(before_render_called).to be true
      end

      it "does not call before_render when child is already in the registry" do
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {["child", 42] => {id: 42, name: "existing"}}
        child = child_klass.new

        child.define_singleton_method(:before_render) { |_ctx| raise "should not be called" }

        expect { serializer.send(:render_child, child, context, {}) }.not_to raise_error
      end
    end
  end
end
