# frozen_string_literal: true

RSpec.describe "ResourceIncludeable" do
  let(:raw_authors) { ["raw_author_1", "raw_author_2"] }
  let(:preloaded_authors) { ["preloaded_author_1", "preloaded_author_2"] }

  let :author_ser do
    Class.new do
      include Halitosis

      resource :author
      attribute(:name) { resource }
    end
  end

  let :klass do
    raw = raw_authors
    ser = author_ser

    Class.new do
      include Halitosis
      include Halitosis::Relationships

      resource :article

      relationship(:authors) { |preloaded = nil| preloaded || raw.map { |a| ser.new(a) } }
    end
  end

  def author_names(result)
    result.dig(:article, :_relationships, :authors)&.map { |a| a[:name] } || []
  end

  context "without an include param" do
    it "does not invoke any preload block" do
      invoked = false
      klass.allow_include(:authors) { |_v|
        invoked = true
        nil
      }

      klass.new(double("article")).render
      expect(invoked).to be false
    end
  end

  context "with a declaration-only top-level allow_include" do
    before { klass.allow_include(:authors) }

    it "renders the relationship using the raw value" do
      result = klass.new(double("article")).render(include: {authors: true})
      expect(author_names(result)).to eq(raw_authors)
    end
  end

  context "with a flat allow_include with preload" do
    it "uses the preloaded value returned by the block when rendering the relationship" do
      pre = preloaded_authors
      ser = author_ser

      klass.allow_include(:authors) { |_v| pre.map { |a| ser.new(a) } }

      result = klass.new(double("article")).render(include: {authors: true})
      expect(author_names(result)).to eq(preloaded_authors)
    end

    it "uses the raw relationship value when the block returns nil" do
      klass.allow_include(:authors) { |_v| nil }

      result = klass.new(double("article")).render(include: {authors: true})
      expect(author_names(result)).to eq(raw_authors)
    end

    it "calls the block with nil when no preload: method is set on the relationship" do
      received = :not_called
      klass.allow_include(:authors) { |v|
        received = v
        nil
      }

      klass.new(double("article")).render(include: {authors: true})
      expect(received).to be_nil
    end

    it "does not call the block when a non-matching include is requested" do
      klass.class_eval { relationship(:comments) { nil } }

      invoked = false
      klass.allow_include(:authors) { |_v|
        invoked = true
        nil
      }

      klass.new(double("article")).render(include: {comments: true})
      expect(invoked).to be false
    end
  end

  context "with a nested deeper path" do
    before { author_ser.relationship(:comments) { nil } }

    it "fires only the deepest matching field for authors.comments" do
      fired = []
      klass.allow_include(:authors) do
        preload ->(_v) {
          fired << :authors
          nil
        }
        allow_include(:comments) { |_v|
          fired << :comments
          nil
        }
      end

      klass.new(double("article")).render(include: {authors: {comments: true}})
      expect(fired).to eq([:comments])
    end

    it "fires the parent preload when only the parent is requested" do
      fired = []
      klass.allow_include(:authors) do
        preload ->(_v) {
          fired << :authors
          nil
        }
        allow_include(:comments) { |_v|
          fired << :comments
          nil
        }
      end

      klass.new(double("article")).render(include: {authors: true})
      expect(fired).to eq([:authors])
    end
  end

  context "when using string include syntax" do
    it "fires the matching field for a shallow string include" do
      received = :not_called
      klass.allow_include(:authors) { |v|
        received = v
        nil
      }

      klass.new(double("article")).render(include: "authors")
      expect(received).not_to eq(:not_called)
    end
  end
end
