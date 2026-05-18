# frozen_string_literal: true

RSpec.describe Halitosis::Includeable do
  let :serializer_klass do
    Class.new do
      include Halitosis::Base
      include Halitosis::Includeable
    end
  end

  describe "context query_params — include param" do
    it "does not register an include key when no include param is present" do
      context = render_context(serializer_klass.new)

      expect(context.query_params).to eq({})
    end

    it "registers a string include param" do
      context = render_context(serializer_klass.new(include: "articles,comments"))

      expect(context.query_params).to eq(include: "articles,comments")
    end

    it "registers a symbol include param" do
      context = render_context(serializer_klass.new(include: :articles))

      expect(context.query_params).to eq(include: "articles")
    end

    it "registers an array include param" do
      context = render_context(serializer_klass.new(include: ["articles", "comments"]))

      expect(context.query_params).to eq(include: "articles,comments")
    end

    it "registers a nested hash include param as dot-notation" do
      context = render_context(serializer_klass.new(include: {"articles" => {"comments" => {}}}))

      expect(context.query_params).to eq(include: "articles.comments")
    end

    it "registers a shallow hash include param" do
      context = render_context(serializer_klass.new(include: {"articles" => {}, "comments" => {}}))

      expect(context.query_params).to eq(include: "articles,comments")
    end

    it "does not register an include key when the value is blank" do
      context = render_context(serializer_klass.new(include: ""))

      expect(context.query_params).to eq({})
    end

    it "does not register an include key when the array is empty" do
      context = render_context(serializer_klass.new(include: []))

      expect(context.query_params).to eq({})
    end
  end

  describe "#normalize_include_param" do
    let(:serializer) { serializer_klass.new }

    it "returns nil for nil" do
      expect(serializer.send(:normalize_include_param, nil)).to be_nil
    end

    it "returns nil for an empty string" do
      expect(serializer.send(:normalize_include_param, "")).to be_nil
    end

    it "returns the string unchanged when non-empty" do
      expect(serializer.send(:normalize_include_param, "articles")).to eq("articles")
    end

    it "converts a symbol to a string" do
      expect(serializer.send(:normalize_include_param, :articles)).to eq("articles")
    end

    it "joins an array with commas" do
      expect(serializer.send(:normalize_include_param, ["a", "b"])).to eq("a,b")
    end

    it "flattens nested arrays" do
      expect(serializer.send(:normalize_include_param, [["a", "b"], "c"])).to eq("a,b,c")
    end

    it "expands a hash to dot-notation paths" do
      expect(serializer.send(:normalize_include_param, {articles: {comments: {}}})).to eq("articles.comments")
    end

    it "expands multiple top-level hash keys" do
      result = serializer.send(:normalize_include_param, {articles: {}, comments: {}})
      expect(result).to eq("articles,comments")
    end
  end
end
