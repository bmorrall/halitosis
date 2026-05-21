# frozen_string_literal: true

RSpec.describe Halitosis::Attributes::Field do
  let(:klass) do
    Class.new do
      include Halitosis::Base
      include Halitosis::Attributes
    end
  end

  def build_context(**options)
    klass.new.send(:build_context, **options)
  end

  describe "#enabled?" do
    context "when no sparse fieldset is active" do
      it "is true for an unguarded field" do
        field = described_class.new(:title, {}, nil)
        context = build_context

        expect(field.enabled?(context)).to be(true)
      end

      it "respects the :if guard" do
        field = described_class.new(:title, {if: false}, nil)
        context = build_context

        expect(field.enabled?(context)).to be(false)
      end
    end

    context "when a sparse fieldset is stored in the context" do
      let(:field) { described_class.new(:title, {}, nil) }

      let(:context) do
        build_context.tap { |c| c.store_local(:current_sparse_fields, Set["title", "body"]) }
      end

      it "is true when the field name is in the allowed set" do
        expect(field.enabled?(context)).to be(true)
      end

      it "is false when the field name is not in the allowed set" do
        other = described_class.new(:author, {}, nil)

        expect(other.enabled?(context)).to be(false)
      end

      it "is false when the :if guard fails even if the field name is allowed" do
        guarded = described_class.new(:title, {if: false}, nil)

        expect(guarded.enabled?(context)).to be(false)
      end
    end
  end
end
