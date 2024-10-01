# frozen_string_literal: true

RSpec.describe Halitosis::Relationships do
  let :klass do
    Class.new do
      include Halitosis
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

        it "returns empty hash when Relationships are requested" do
          serializer = klass.new(include: {foo: true})

          expect(serializer.relationships).to eq({})
        end
      end

      describe "when Relationships are defined" do
        before do
          klass.rel(:just_nil, {}) { nil }
          klass.rel(:non_repr, {}) { "some object" }
          klass.rel(:child_repr, {}) { child }

          klass.send(:define_method, :child) do
            # just build another serializer instance to be rendered
            Class.new { include Halitosis }.new
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

      let :child_class do
        Class.new do
          include Halitosis

          property(:foo) { "bar" }
        end
      end

      let :child do
        child_class.new
      end

      it "returns nil if value is falsey" do
        [nil, false, 0].each do |value|
          expect(serializer.relationships_child(:foo, value)).to be_nil
        end
      end

      describe "when value is an array" do
        it "renders children" do
          array = [child, nil, 0, child, 1]

          result = serializer.relationships_child(:include_key, array)

          expect(result).to eq([{foo: "bar"}, {foo: "bar"}])
        end
      end

      describe "when value is a serializer" do
        it "renders child" do
          result = serializer.relationships_child(:include_key, child)

          expect(result).to eq(foo: "bar")
        end
      end
    end

    describe "#child_relationship_opts" do
      it "returns empty options for unknown key" do
        serializer = klass.new

        opts = serializer.send(:child_relationship_opts, :unknown_key)

        expect(opts).to eq({}).and(be_truthy)
      end

      it "returns empty options for known key with no child options" do
        serializer = klass.new(include: {requested_key: 1})

        opts = serializer.send(:child_relationship_opts, "requested_key")

        expect(opts).to eq({}).and(be_truthy)
      end

      it "returns child options for known key with child options" do
        serializer = klass.new(include: {requested_key: {child_key: 0}})

        opts = serializer.send(:child_relationship_opts, "requested_key")

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

        opts = serializer.send(:child_relationship_opts, "requested_key")

        expect(opts).to eq(
          child_key: {grandchild_key: {great_grandchild_key: 1}}
        ).and(be_truthy)
      end
    end

    describe "#include_options" do
      it "stringifies nested keys" do
        serializer = klass.new(include: {some: {options: 1}})

        expect(serializer.include_options).to eq("some" => {options: 1})
      end

      ["some.options", "more.options.here", "more.options.there", "another"].permutation.each do |permutation|
        it "hashifies an array of strings #{permutation.join(",")}" do
          serializer = klass.new(include: permutation)

          expect(serializer.include_options).to eq(
            "some" => {
              "options" => {}
            },
            "more" => {
              "options" => {
                "here" => {},
                "there" => {}
              }
            },
            "another" => {}
          )
        end

        it "hashifies an array of symbols #{permutation.join(",")}" do
          serializer = klass.new(include: permutation.map(&:to_sym))

          expect(serializer.include_options).to eq(
            "some" => {
              "options" => {}
            },
            "more" => {
              "options" => {
                "here" => {},
                "there" => {}
              }
            },
            "another" => {}
          )
        end

        it "hashifies a comma separated string #{permutation.join(",")}" do
          serializer = klass.new(include: permutation.join(","))

          expect(serializer.include_options).to eq(
            "some" => {
              "options" => {}
            },
            "more" => {
              "options" => {
                "here" => {},
                "there" => {}
              }
            },
            "another" => {}
          )
        end
      end

      it "handles nil" do
        serializer = klass.new(include: nil)

        expect(serializer.include_options).to eq({})
      end
    end
  end
end
