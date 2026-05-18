# frozen_string_literal: true

RSpec.describe Halitosis::ResourceRelationships do
  let :klass do
    Class.new do
      include Halitosis::Base
      include Halitosis::Preloadable
      include Halitosis::ResourceRelationships
    end
  end

  describe Halitosis::ResourceRelationships::ClassMethods do
    describe "#relationship" do
      it "adds simple relationship field" do
        expect(klass.fields).to receive(:add).with(kind_of(Halitosis::ResourceRelationships::Field))

        klass.relationship(:foo, {}) { "bar" }
      end
    end

    describe "#rel" do
      it "adds simple relationship field" do
        expect(klass.fields).to receive(:add).with(kind_of(Halitosis::ResourceRelationships::Field))

        klass.rel(:foo, {}) { "bar" }
      end
    end
  end

  describe Halitosis::ResourceRelationships::InstanceMethods do
    describe "#relationships" do
      describe "when no Relationships are defined" do
        it "returns empty hash when no Relationships are requested" do
          serializer = klass.new

          expect(serializer.relationships).to eq({})
        end

        it "raises an error when an unknown resource is requested" do
          serializer = klass.new(include: {foo: true})

          expect do
            serializer.relationships
          end.to raise_error do |exception|
            expect(exception).to be_an_instance_of(Halitosis::InvalidIncludeParameter)
            expect(exception.message).to match(/does not have a `foo` relationship path/i)
            expect(exception.parameter).to eq("include")
          end
        end
      end

      describe "when Relationships are defined" do
        before do
          klass.rel(:just_nil, {}) { nil }
          klass.rel(:empty_array, {}) { [] }
          klass.rel(:non_repr, {}) { "some object" }
          klass.rel(:child_repr, {}) { child }

          klass.send(:define_method, :child) do
            # just build another serializer instance to be rendered
            Class.new { include Halitosis::Base }.new
          end
        end

        it "returns empty hash when no Relationships are requested" do
          serializer = klass.new(include: {})

          expect(serializer.relationships).to eq({})
        end

        it "builds relationships resources as expected" do
          include_opts = {just_nil: true, empty_array: true, non_repr: true, child_repr: true}

          serializer = klass.new(include: include_opts)

          expect(serializer.relationships).to eq(just_nil: nil, empty_array: [], non_repr: nil, child_repr: {})
        end

        it "passes the stored preload to an arity-1 relationship block" do
          child_class = Class.new {
            include Halitosis::Base
            include Halitosis::Attributes

            attribute(:id, value: 1)
          }

          klass.rel(:with_preload, {}) { |preloaded| preloaded }

          serializer = klass.new(include: {with_preload: true})
          context = serializer.send(:build_context)
          serializer.send(:store_preload, context, :with_preload, proc { child_class.new })

          result = serializer.relationships(context)

          expect(result[:with_preload]).to eq(id: 1)
        end

        it "uses the preload: option key for the preload lookup" do
          child_class = Class.new {
            include Halitosis::Base
            include Halitosis::Attributes

            attribute(:id, value: 2)
          }

          klass.rel(:articles, {preload: :user_articles}) { |preloaded| preloaded }

          serializer = klass.new(include: {articles: true})
          context = serializer.send(:build_context)
          serializer.send(:store_preload, context, :user_articles, proc { child_class.new })

          result = serializer.relationships(context)

          expect(result[:articles]).to eq(id: 2)
        end

        it "evaluates a shared preload key once across multiple relationships" do
          call_count = 0
          child_class = Class.new {
            include Halitosis::Base
            include Halitosis::Attributes

            attribute(:id, value: 42)
          }

          klass.rel(:rel_a, {preload: :shared}) { |data| data }
          klass.rel(:rel_b, {preload: :shared}) { |data| data }
          klass.rel(:rel_c, {preload: :shared}) { |data| data }

          klass.define_method(:shared) do
            call_count += 1
            child_class.new
          end

          serializer = klass.new(include: {rel_a: true, rel_b: true, rel_c: true})
          result = serializer.relationships

          expect(call_count).to eq(1)
          expect(result[:rel_a]).to eq(id: 42)
          expect(result[:rel_b]).to eq(id: 42)
          expect(result[:rel_c]).to eq(id: 42)
        end

        it "uses a manually stored value even when preload: false" do
          child_class = Class.new {
            include Halitosis::Base
            include Halitosis::Attributes

            attribute(:id, value: 99)
          }

          klass.rel(:opted_out, {preload: false}) { |preloaded| preloaded }

          serializer = klass.new(include: {opted_out: true})
          context = serializer.send(:build_context)
          serializer.send(:store_preload, context, :opted_out, proc { child_class.new })

          result = serializer.relationships(context)

          expect(result[:opted_out]).to eq(id: 99)
        end

        it "does not lazy-load when preload: false and nothing is stored" do
          call_count = 0

          klass.rel(:opted_out, {preload: false}) { |preloaded| preloaded }
          klass.define_method(:opted_out) { call_count += 1 }

          serializer = klass.new(include: {opted_out: true})
          serializer.relationships

          expect(call_count).to eq(0)
        end
      end
    end

    describe "#before_render" do
      it "pre-populates preload storage for enabled preload: fields before rendering" do
        populated_before_render = nil
        child_class = Class.new {
          include Halitosis::Base
          include Halitosis::Attributes

          attribute(:id, value: 7)
        }

        klass.rel(:item, {preload: :item_data}) { |data| data }
        klass.define_method(:item_data) { child_class.new }

        original_render_with_context = klass.instance_method(:render_with_context)
        klass.define_method(:render_with_context) do |ctx|
          populated_before_render = send(:preloaded?, ctx, :item_data)
          original_render_with_context.bind_call(self, ctx)
        end

        serializer = klass.new(include: {item: true})
        serializer.render

        expect(populated_before_render).to be(true)
      end

      it "does not pre-populate preloads for excluded relationship fields" do
        call_count = 0
        child_class = Class.new { include Halitosis::Base }

        klass.rel(:item, {preload: :item_data}) { |data| data }
        klass.define_method(:item_data) {
          call_count += 1
          child_class.new
        }

        # item is NOT included
        klass.new(include: {}).render

        expect(call_count).to eq(0)
      end
    end

    describe "#relationships_child" do
      let :serializer do
        klass.new
      end
      let(:context) { serializer.send(:build_context) }

      let :child_class do
        Class.new do
          include Halitosis::Base
          include Halitosis::Attributes

          attribute(:foo) { "bar" }
        end
      end

      let :child do
        child_class.new
      end

      it "returns nil if value is falsey" do
        [nil, false, 0].each do |value|
          expect(serializer.relationships_child(:foo, context, value)).to be_nil
        end
      end

      describe "when value is an array" do
        it "renders children" do
          array = [child, nil, 0, child, 1]

          result = serializer.relationships_child(:include_key, context, array)

          expect(result).to eq([{foo: "bar"}, {foo: "bar"}])
        end
      end

      describe "when value is a serializer" do
        it "renders child" do
          result = serializer.relationships_child(:include_key, context, child)

          expect(result).to eq(foo: "bar")
        end
      end
    end

    describe "#child_relationship_opts" do
      it "returns empty options for unknown key" do
        serializer = klass.new
        context = serializer.send(:build_context)

        opts = serializer.send(:child_relationship_opts, :unknown_key, context)

        expect(opts).to eq({}).and(be_truthy)
      end

      it "returns empty options for known key with no child options" do
        serializer = klass.new(include: {requested_key: 1})
        context = serializer.send(:build_context)

        opts = serializer.send(:child_relationship_opts, "requested_key", context)

        expect(opts).to eq({}).and(be_truthy)
      end

      it "returns child options for known key with child options" do
        serializer = klass.new(include: {requested_key: {child_key: 0}})
        context = serializer.send(:build_context)

        opts = serializer.send(:child_relationship_opts, "requested_key", context)

        expect(opts).to eq(child_key: 0).and(be_truthy)
      end

      it "returns deeply nested child options" do
        serializer = klass.new(
          include: {
            requested_key: {
              child_key: {grandchild_key: {great_grandchild_key: 1}}
            }
          }
        )
        context = serializer.send(:build_context)

        opts = serializer.send(:child_relationship_opts, "requested_key", context)

        expect(opts).to eq(
          child_key: {grandchild_key: {great_grandchild_key: 1}}
        ).and(be_truthy)
      end
    end
  end
end
