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

    it "does not store preload options on the field" do
      field = described_class.new(:author, {}, proc { |val| val })

      expect(field.options).not_to have_key(:preload)
      expect(field.validate).to be(true)
    end

    it "does not raise when called without a preload option" do
      expect {
        described_class.new(:author, {}, proc { |val| val }).validate
      }.not_to raise_error
    end

    it "does not raise when called with a zero-arity block" do
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
      it "passes preloaded value as argument" do
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

  # preload? and preload_key behaviour is now owned by
  # ResourcePreloader::Field — see
  # spec/halitosis/resource_preloader/field_spec.rb
end
