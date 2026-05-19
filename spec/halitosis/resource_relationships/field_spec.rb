RSpec.describe Halitosis::ResourceRelationships::Field do
  let :klass do
    Class.new {
      include Halitosis::Base
      include Halitosis::ResourceRelationships
    }
  end

  describe "#validate" do
    it "returns true with procedure" do
      result = described_class.new(:name, {}, proc {}).validate

      expect(result).to be(true)
    end

    it "raises exception without procedure" do
      expect {
        described_class.new(:name, {}, nil).validate
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidField)
        expect(exception.message).to(
          eq("Relationship name must be defined with a proc")
        )
      end
    end

    it "raises when block accepts arguments but no preload: is set" do
      expect {
        described_class.new(:author, {}, proc { |val| val }).validate
      }.to raise_error(Halitosis::InvalidField, "Relationship author block accepts arguments but no `preload:` option is set")
    end

    it "does not raise when preload: false is set alongside an arity-1 block" do
      expect {
        described_class.new(:author, {preload: false}, proc { |val| val }).validate
      }.not_to raise_error
    end

    it "does not raise when preload: true is set alongside an arity-1 block" do
      expect {
        described_class.new(:author, {preload: true}, proc { |val| val }).validate
      }.not_to raise_error
    end

    it "does not raise for a zero-arity block without preload:" do
      expect {
        described_class.new(:author, {}, proc {}).validate
      }.not_to raise_error
    end
  end

  describe "#enabled?" do
    let :klass do
      Class.new {
        include Halitosis::Base
        include Halitosis::ResourceRelationships
      }
    end

    [1, 2, true, "1", "2", "true", "yes"].each do |value|
      it "is true for expected values #{value.inspect}" do
        context = klass.new(include: {foo: value}).send(:build_context)

        relationship = described_class.new(:foo, {}, proc {})

        expect(relationship.send(:enabled?, context)).to be(true)
      end
    end

    [0, false, "0", "false"].each do |value|
      it "is false for expected values #{value.inspect}" do
        context = klass.new(include: {foo: value}).send(:build_context)

        relationship = described_class.new(:foo, {}, proc {})

        expect(relationship.send(:enabled?, context)).to be(false)
      end
    end

    it "is false by default" do
      context = klass.new.send(:build_context)

      relationship = described_class.new(:foo, {}, proc {})

      expect(relationship.send(:enabled?, context)).to be(false)
    end
  end

  describe "#value" do
    context "when the procedure has arity 0" do
      it "calls the procedure without the preloaded value" do
        context = klass.new(include: {articles: true}).send(:build_context)
        field = described_class.new(:articles, {}, proc { "direct" })

        expect(field.value(context)).to eq("direct")
      end
    end

    context "when the procedure has arity 1" do
      it "passes the preloaded value as the first argument" do
        context = klass.new(include: {articles: true}).send(:build_context)
        field = described_class.new(:articles, {}, proc { |articles| articles })

        expect(field.value(context, ["preloaded"])).to eq(["preloaded"])
      end

      it "passes nil when no preloaded value is given" do
        context = klass.new(include: {articles: true}).send(:build_context)
        field = described_class.new(:articles, {}, proc { |articles| articles })

        expect(field.value(context, nil)).to be_nil
      end
    end
  end

  describe "#preload?" do
    it "returns true when preload option is set and field is enabled" do
      context = klass.new(include: {articles: true}).send(:build_context)
      field = described_class.new(:articles, {preload: :user_articles}, proc {})

      expect(field.preload?(context)).to be(true)
    end

    it "returns false when preload option is set but field is not included" do
      context = klass.new(include: {}).send(:build_context)
      field = described_class.new(:articles, {preload: :user_articles}, proc {})

      expect(field.preload?(context)).to be(false)
    end

    it "returns false when preload: false even if field is enabled" do
      context = klass.new(include: {articles: true}).send(:build_context)
      field = described_class.new(:articles, {preload: false}, proc {})

      expect(field.preload?(context)).to be(false)
    end
  end

  describe "#preload_key" do
    it "defaults to the field name" do
      field = described_class.new(:articles, {}, proc {})

      expect(field.preload_key).to eq(:articles)
    end

    it "returns the preload option as a symbol when set" do
      field = described_class.new(:articles, {preload: :user_articles}, proc {})

      expect(field.preload_key).to eq(:user_articles)
    end

    it "converts a string preload option to a symbol" do
      field = described_class.new(:articles, {preload: "user_articles"}, proc {})

      expect(field.preload_key).to eq(:user_articles)
    end

    it "defaults to the field name when preload: false" do
      field = described_class.new(:articles, {preload: false}, proc {})

      expect(field.preload_key).to eq(:articles)
    end

    it "defaults to the field name when preload: true" do
      field = described_class.new(:articles, {preload: true}, proc {})

      expect(field.preload_key).to eq(:articles)
    end
  end

  describe "#validate", "preload option" do
    it "raises when preload option is not a String, Symbol, true, or false" do
      expect {
        described_class.new(:articles, {preload: 123}, proc {}).validate
      }.to raise_error do |exception|
        expect(exception).to be_an_instance_of(Halitosis::InvalidField)
        expect(exception.message).to eq("Relationship articles preload option must be a Symbol, String, true, or false")
      end
    end

    it "is valid with preload: false" do
      expect(described_class.new(:articles, {preload: false}, proc {}).validate).to be(true)
    end

    it "is valid with preload: true" do
      expect(described_class.new(:articles, {preload: true}, proc {}).validate).to be(true)
    end
  end
end
