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

      relationship :child do
        child_klass.new
      end
    end
  end

  it "is included in every serializer by default" do
    expect(klass.ancestors).to include(Halitosis::CollectIncludes::InstanceMethods)
  end

  describe ".legacy_nesting!" do
    let :legacy_klass do
      child_klass = self.child_klass

      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        legacy_nesting!

        relationship :child do
          child_klass.new
        end
      end
    end

    it "is disabled by default" do
      expect(klass.legacy_nesting?).to be false
    end

    it "enables legacy nesting" do
      expect(legacy_klass.legacy_nesting?).to be true
    end

    it "is inherited by subclasses" do
      expect(Class.new(legacy_klass).legacy_nesting?).to be true
    end

    it "renders included relationships inline with a _type in addition to _included" do
      result = legacy_klass.new(include: {child: true}).render

      expect(result).to eq(
        _relationships: {child: {id: 42, _type: "child", name: "child"}},
        _included: {child: [{id: 42, name: "child"}]}
      )
    end

    it "does not add an included key when no relationships are included" do
      expect(legacy_klass.new.render).to eq({})
    end
  end

  describe Halitosis::CollectIncludes::InstanceMethods do
    describe "#render" do
      context "when no relationships are included" do
        it "does not add an included key" do
          serializer = klass.new

          result = serializer.render
          expect(result).not_to have_key(:_included)
        end
      end

      context "when a relationship is included but returns nil" do
        it "renders an empty included hash" do
          klass = Class.new do
            include Halitosis
            include Halitosis::ResourceRelationships

            relationship :child do
              nil
            end
          end

          result = klass.new(include: {child: true}).render

          expect(result[:_relationships][:child]).to be_nil
          expect(result[:_included]).to eq({})
        end
      end

      context "when a relationship is included" do
        it "stubs the relationship and adds the full payload to included" do
          serializer = klass.new(include: {child: true})

          result = serializer.render
          expect(result[:_relationships][:child]).to eq(id: 42, _type: "child")
          expect(result[:_included]).to eq(child: [{id: 42, name: "child"}])
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

      it "renders the child inline with a _type when no included_registry on context (legacy nesting)" do
        serializer = klass.new
        child = child_klass.new
        opts = {}

        result = serializer.send(:render_child, child, context_without_registry, opts)
        expect(result).to eq(id: 42, _type: "child", name: "child")
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

      it "re-renders a child already in the registry when new include options are requested" do
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {["child", 42] => {id: 42, name: "existing"}}
        context.included_include_options[["child", 42]] = {"child" => {}}
        child = child_klass.new

        allow(child).to receive(:render_with_context).and_return(id: 42, name: "rerendered")
        result = serializer.send(:render_child, child, context, {child: {child: true}})

        expect(result).to eq(id: 42, _type: "child")
        expect(context.included_registry[["child", 42]]).to eq(id: 42, name: "rerendered")
        expect(context.included_include_options[["child", 42]]).to eq("child" => {"child" => {}})
      end

      it "does not re-render when the requested include options are already covered" do
        serializer = klass.new
        context = Halitosis::Context.new(serializer, {})
        context.included_registry = {["child", 42] => {id: 42, name: "existing"}}
        context.included_include_options[["child", 42]] = {"child" => {"child" => {}}}
        child = child_klass.new

        expect(child).not_to receive(:render_with_context)
        serializer.send(:render_child, child, context, {"child" => true})
      end
    end
  end
end
