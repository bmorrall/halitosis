# frozen_string_literal: true

RSpec.describe Halitosis::CollectIncludes do
  let :child_klass do
    Class.new do
      include Halitosis
      include Halitosis::Relationships

      identifier :id, value: 42
      attribute(:name) { "child" }

      define_singleton_method(:resource_type) { "child" }
    end
  end

  let :klass do
    child_klass = self.child_klass

    Class.new do
      include Halitosis
      include Halitosis::Relationships

      collect_includes

      attribute(:name) { "root" }

      relationship :child do
        child_klass.new
      end
    end
  end

  describe ".collect_includes" do
    it "includes CollectIncludes::InstanceMethods" do
      expect(klass.ancestors).to include(Halitosis::CollectIncludes::InstanceMethods)
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

      context "when a relationship is included" do
        it "stubs the relationship and adds the full payload to included" do
          serializer = klass.new(include: {child: true})

          result = serializer.render
          expect(result[:_relationships][:child]).to eq(id: 42, _type: "child")
          expect(result[:included]).to eq([{id: 42, name: "child"}])
        end
      end
    end

    describe "#render_child" do
      let(:context_without_registry) do
        Halitosis::Context.new(klass.new, {})
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
        serializer.instance_variable_set(:@_collect_includes_registry, {})
        context = Halitosis::Context.new(serializer, {})
        child = no_id_klass.new

        result = serializer.send(:render_child, child, context, {})
        expect(result).to eq(name: "no id")
        expect(serializer.instance_variable_get(:@_collect_includes_registry)).to be_empty
      end

      it "stores the full payload in the registry and returns a stub" do
        registry = {}
        serializer = klass.new
        serializer.instance_variable_set(:@_collect_includes_registry, registry)
        context = Halitosis::Context.new(serializer, {})
        child = child_klass.new

        result = serializer.send(:render_child, child, context, {})
        expect(result).to eq(id: 42, _type: "child")
        expect(registry).to eq(["child", 42] => {id: 42, name: "child"})
      end

      it "does not re-render a child already in the registry" do
        registry = {["child", 42] => {id: 42, name: "existing"}}
        serializer = klass.new
        serializer.instance_variable_set(:@_collect_includes_registry, registry)
        context = Halitosis::Context.new(serializer, {})
        child = child_klass.new

        expect(child).not_to receive(:render_with_context)
        result = serializer.send(:render_child, child, context, {})

        expect(result).to eq(id: 42, _type: "child")
        expect(registry[["child", 42]][:name]).to eq("existing")
      end

      it "extends child instances with InstanceMethods for recursive stubbing" do
        serializer = klass.new
        serializer.instance_variable_set(:@_collect_includes_registry, {})
        context = Halitosis::Context.new(serializer, {})
        child = child_klass.new

        serializer.send(:render_child, child, context, {})
        expect(child).to be_a(Halitosis::CollectIncludes::InstanceMethods) # rubocop:disable RSpec/DescribedClass
      end
    end
  end
end
