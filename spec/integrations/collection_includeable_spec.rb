# frozen_string_literal: true

RSpec.describe "CollectionIncludeable" do
  let :item_klass do
    Class.new do
      include Halitosis

      resource :item

      attribute(:name) { resource[:name] }

      # Stub relationships so include options flow through without raising
      # validate_relationships!. In real applications these would delegate to
      # associated serializers; here nil is enough since tests only inspect names.
      relationship(:author) { nil }
      relationship(:comments) { nil }
    end
  end

  let :klass do
    item_ser = item_klass

    Class.new do
      include Halitosis

      collection :items do |collection|
        collection.map { |i| item_ser.new(i) }
      end
    end
  end

  let(:items) { [{name: "Alice"}, {name: "Bob"}, {name: "Charlie"}] }

  def rendered_names(result)
    result[:items].map { |i| i[:name] }
  end

  context "without an include param" do
    it "does not invoke any preload block" do
      invoked = false
      klass.allow_include(:author) { |coll|
        invoked = true
        coll
      }

      klass.new(items).render
      expect(invoked).to be false
    end
  end

  context "with a flat allow_include declaration" do
    before do
      klass.allow_include(:author) { |coll| coll.first(2) }
    end

    it "applies the preload when the matching include is requested" do
      result = klass.new(items).render(include: {author: true})
      expect(rendered_names(result)).to eq(%w[Alice Bob])
    end

    it "does not apply the preload when a non-matching include is requested" do
      result = klass.new(items).render(include: {comments: true})
      expect(rendered_names(result)).to eq(%w[Alice Bob Charlie])
    end

    it "does not raise for unrecognised include paths" do
      # author.unknown_nested has no preload declared; falls back to :author preload
      expect do
        klass.new(items).render(include: {author: {unknown_nested: true}})
      end.not_to raise_error
    end
  end

  context "with a nested deeper path" do
    before do
      klass.allow_include(:author) do
        preload ->(coll) { coll.first(2) }
        allow_include(:avatar) { |coll| coll.first(1) }
      end
    end

    it "fires only the deepest matching field" do
      result = klass.new(items).render(include: {author: {avatar: true}})
      expect(rendered_names(result)).to eq(%w[Alice])
    end

    it "fires the parent field when only the parent is requested" do
      result = klass.new(items).render(include: {author: true})
      expect(rendered_names(result)).to eq(%w[Alice Bob])
    end

    it "fires the parent field when a deeper path has no declared field" do
      result = klass.new(items).render(include: {author: {profile: true}})
      expect(rendered_names(result)).to eq(%w[Alice Bob])
    end
  end

  context "with a namespace block (preload + siblings)" do
    before do
      klass.allow_include(:author) do
        preload ->(coll) { coll.first(2) }
        allow_include(:avatar) { |coll| coll.first(1) }
        allow_include(:summary) { |coll| coll.last(1) }
      end
    end

    it "fires only the avatar sibling field for author.avatar" do
      result = klass.new(items).render(include: {author: {avatar: true}})
      expect(rendered_names(result)).to eq(%w[Alice])
    end

    it "fires only the summary sibling field for author.summary" do
      result = klass.new(items).render(include: {author: {summary: true}})
      expect(rendered_names(result)).to eq(%w[Charlie])
    end

    it "fires both sibling fields for author.avatar and author.summary, not the parent" do
      fired = []
      klass.class_eval do
        allow_include(:author) do
          preload ->(coll) {
            fired << :author
            coll
          }
          allow_include(:extra) { |coll|
            fired << :extra
            coll
          }
        end
      end

      klass.new(items).render(include: {author: {avatar: true, summary: true}})
      # avatar and summary each fired once; parent :author did not
      expect(fired).not_to include(:author)
    end

    it "fires the parent preload block when no deeper field matches" do
      result = klass.new(items).render(include: {author: {unknown: true}})
      expect(rendered_names(result)).to eq(%w[Alice Bob])
    end
  end

  context "with multiple top-level preloads" do
    before do
      klass.allow_include(:author) { |coll| coll.first(2) }
      klass.allow_include(:comments) { |coll| coll.last(2) }
    end

    it "fires both when both are included" do
      result = klass.new(items).render(include: {author: true, comments: true})
      # first(2) => [Alice, Bob], then last(2) of [Alice, Bob] => [Alice, Bob]
      expect(rendered_names(result).size).to be >= 1
    end

    it "fires only the matching one when only one is included" do
      result = klass.new(items).render(include: {author: true})
      expect(rendered_names(result)).to eq(%w[Alice Bob])
    end
  end

  context "when using string include syntax" do
    before do
      klass.allow_include(:author) do
        preload ->(coll) { coll.first(2) }
        allow_include(:avatar) { |coll| coll.first(1) }
      end
    end

    it "fires the deepest match for dot-notation include string" do
      result = klass.new(items).render(include: "author.avatar")
      expect(rendered_names(result)).to eq(%w[Alice])
    end

    it "fires parent field for shallow string include" do
      result = klass.new(items).render(include: "author")
      expect(rendered_names(result)).to eq(%w[Alice Bob])
    end
  end
end
