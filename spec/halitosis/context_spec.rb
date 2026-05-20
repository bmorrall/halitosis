RSpec.describe Halitosis::Context do
  describe "#parent" do
    context "when a parent is present" do
      it "returns the parent" do
        parent = described_class.new(nil)
        context = described_class.new(nil, parent: parent)
        expect(context.parent).to eq(parent)
      end
    end

    context "when parent is nil" do
      it "returns nil" do
        context = described_class.new(nil)
        expect(context.parent).to be_nil
      end
    end
  end

  describe "#depth" do
    context "when a parent is present" do
      it "returns the parent's depth plus 1" do
        grandparent = described_class.new(nil)
        expect(grandparent.depth).to eq(0)

        parent = described_class.new(nil, parent: grandparent)
        expect(parent.depth).to eq(1)

        context = described_class.new(nil, parent: parent)
        expect(context.depth).to eq(2)
      end
    end

    context "when parent is nil" do
      it "returns 0" do
        context = described_class.new(nil)
        expect(context.depth).to eq(0)
      end
    end
  end

  describe "#root?" do
    context "when no parent is present" do
      it "returns true" do
        context = described_class.new(nil)
        expect(context.root?).to be(true)
      end
    end

    context "when a parent is present" do
      it "returns false" do
        parent = described_class.new(nil)
        context = described_class.new(nil, parent: parent)
        expect(context.root?).to be(false)
      end
    end
  end

  describe "#include_options" do
    it "stringifies nested keys" do
      context = described_class.new(nil, include: {some: {options: 1}})

      expect(context.include_options).to eq("some" => {options: 1})
    end

    ["some.options", "more.options.here", "more.options.there", "another"].permutation.each do |permutation|
      it "hashifies an array of strings #{permutation.join(",")}" do
        context = described_class.new(nil, include: permutation)

        expect(context.include_options).to eq(
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
        context = described_class.new(nil, include: permutation.map(&:to_sym))

        expect(context.include_options).to eq(
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
        context = described_class.new(nil, include: permutation.join(","))

        expect(context.include_options).to eq(
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
      context = described_class.new(nil, include: nil)

      expect(context.include_options).to eq({})
    end
  end

  describe "#call_instance" do
    let(:instance) do
      Class.new do
        def some_method = "result"
      end.new
    end
    let(:context) { described_class.new(instance) }

    context "when guard is a Proc" do
      it "evaluates the proc in the context of the instance" do
        guard = proc { |_ctx| 42 }
        expect(context.call_instance(guard)).to eq(42)
      end
    end

    context "when guard is a Symbol" do
      it "sends the method to the instance" do
        expect(context.call_instance(:some_method)).to eq("result")
      end
    end

    context "when guard is a String" do
      it "sends the method to the instance" do
        expect(context.call_instance("some_method")).to eq("result")
      end
    end

    context "when guard is another value" do
      it "returns the value as-is" do
        expect(context.call_instance(true)).to be(true)
        expect(context.call_instance(false)).to be(false)
      end
    end
  end

  describe "#call_instance with args" do
    let(:instance) do
      Class.new do
        def double_it(x) = x * 2
      end.new
    end
    let(:context) { described_class.new(instance) }

    context "when guard is a Proc" do
      it "passes args to the proc" do
        guard = proc { |x| x * 2 }
        expect(context.call_instance(5, guard)).to eq(10)
      end
    end

    context "when guard is a Symbol" do
      it "forwards args to the method" do
        expect(context.call_instance(5, :double_it)).to eq(10)
      end
    end

    context "when guard is a String" do
      it "forwards args to the method" do
        expect(context.call_instance(5, "double_it")).to eq(10)
      end
    end

    context "when guard is another value" do
      it "returns the value as-is" do
        expect(context.call_instance(5, true)).to be(true)
      end
    end
  end

  describe "#call_conditional?" do
    let(:instance) do
      Class.new do
        def condition = nil
      end.new
    end
    let(:context) { described_class.new(instance) }

    context "when options has no :if or :unless key" do
      it "returns true" do
        expect(context.call_conditional?({})).to be(true)
      end
    end

    context "when options has an :if key" do
      it "returns true when the guard is truthy" do
        allow(instance).to receive(:condition).and_return(true)
        expect(context.call_conditional?({if: :condition})).to be(true)
      end

      it "returns false when the guard is falsy" do
        allow(instance).to receive(:condition).and_return(false)
        expect(context.call_conditional?({if: :condition})).to be(false)
      end

      it "accepts a proc" do
        expect(context.call_conditional?({if: ->(_ctx) { true }})).to be(true)
      end
    end

    context "when options has an :unless key" do
      it "returns false when the guard is truthy" do
        allow(instance).to receive(:condition).and_return(true)
        expect(context.call_conditional?({unless: :condition})).to be(false)
      end

      it "returns true when the guard is falsy" do
        allow(instance).to receive(:condition).and_return(false)
        expect(context.call_conditional?({unless: :condition})).to be(true)
      end

      it "accepts a proc" do
        expect(context.call_conditional?({unless: ->(_ctx) { false }})).to be(true)
      end
    end
  end
end
