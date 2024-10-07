# frozen_string_literal: true

RSpec.describe Halitosis::Relationships do
  let :klass do
    Class.new do
      include Halitosis::Base
      include Halitosis::Relationships
    end
  end

  describe Halitosis::Relationships::ClassMethods do
    describe "#relationship" do
      it "adds simple relationship field" do
        expect(klass.fields).to receive(:add).with(kind_of(Halitosis::Relationships::Field))

        klass.relationship(:foo, {}) { "bar" }
      end
    end

    describe "#rel" do
      it "adds simple relationship field" do
        expect(klass.fields).to receive(:add).with(kind_of(Halitosis::Relationships::Field))

        klass.rel(:foo, {}) { "bar" }
      end
    end
  end

  describe Halitosis::Relationships::InstanceMethods do
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
            expect(exception).to be_an_instance_of(Halitosis::InvalidQueryParameter)
            expect(exception.message).to match(/does not have a `foo` relationship path/i)
            expect(exception.parameter).to eq("include")
          end
        end
      end

      describe "when Relationships are defined" do
        before do
          klass.rel(:just_nil, {}) { nil }
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
          include_opts = {just_nil: true, non_repr: true, child_repr: true}

          serializer = klass.new(include: include_opts)

          expect(serializer.relationships).to eq(child_repr: {})
        end
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
