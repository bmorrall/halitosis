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
end
