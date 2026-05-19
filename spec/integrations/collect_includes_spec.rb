# frozen_string_literal: true

RSpec.describe "CollectIncludes" do
  let :author_klass do
    Class.new do
      include Halitosis

      resource :author

      identifier(:id) { resource[:id] }

      attribute(:name) { resource[:name] }
    end
  end

  let :article_klass do
    author_klass = self.author_klass

    Class.new do
      include Halitosis
      include Halitosis::ResourceRelationships

      resource :article

      collect_includes!

      identifier(:id) { resource[:id] }

      attribute(:title) { resource[:title] }

      relationship :author do
        author_klass.new(resource[:author])
      end
    end
  end

  let(:author_attrs) { {id: 10, name: "Alice"} }
  let(:article_attrs) { {id: 1, title: "Hello", author: author_attrs} }

  context "with a single resource and one included relationship" do
    it "stubs the relationship inline and hoists the full payload into included" do
      serializer = article_klass.new(article_attrs, include: {author: true})

      result = serializer.render

      expect(result[:article]).to include(
        id: 1,
        title: "Hello",
        _type: "article",
        _relationships: {author: {id: 10, _type: "author"}}
      )

      expect(result[:included]).to eq([
        {id: 10, name: "Alice", _type: "author"}
      ])
    end

    it "does not add included key when no relationships are included" do
      serializer = article_klass.new(article_attrs)

      result = serializer.render
      expect(result).not_to have_key(:included)
    end
  end

  context "with multiple articles referencing the same author" do
    let :collection_klass do
      article_klass = self.article_klass

      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        collect_includes!

        collection :articles do |articles|
          articles.map { |attrs| article_klass.new(attrs) }
        end
      end
    end

    it "deduplicates the same author across multiple articles" do
      articles = [
        {id: 1, title: "First", author: author_attrs},
        {id: 2, title: "Second", author: author_attrs}
      ]

      serializer = collection_klass.new(articles, include: {author: true})
      result = serializer.render

      expect(result[:included].length).to eq(1)
      expect(result[:included].first).to eq(id: 10, name: "Alice", _type: "author")
    end

    it "includes each distinct author once" do
      bob_attrs = {id: 20, name: "Bob"}
      articles = [
        {id: 1, title: "First", author: author_attrs},
        {id: 2, title: "Second", author: bob_attrs}
      ]

      serializer = collection_klass.new(articles, include: {author: true})
      result = serializer.render

      expect(result[:included].length).to eq(2)
      expect(result[:included]).to contain_exactly(
        {id: 10, name: "Alice", _type: "author"},
        {id: 20, name: "Bob", _type: "author"}
      )
    end
  end

  context "with nested relationships (A -> B -> C)" do
    let :tag_klass do
      Class.new do
        include Halitosis

        resource :tag

        identifier(:id) { resource[:id] }

        attribute(:label) { resource[:label] }
      end
    end

    let :article_with_tags_klass do
      author_klass = self.author_klass
      tag_klass = self.tag_klass

      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :article

        collect_includes!

        identifier(:id) { resource[:id] }

        attribute(:title) { resource[:title] }

        relationship :author do
          author_klass.new(resource[:author])
        end

        relationship :tag do
          tag_klass.new(resource[:tag])
        end
      end
    end

    let :author_with_tag_klass do
      tag_klass = self.tag_klass

      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :author

        identifier(:id) { resource[:id] }

        attribute(:name) { resource[:name] }

        relationship :tag do
          tag_klass.new(resource[:tag])
        end
      end
    end

    it "hoists all depths into included array with stubs at each level" do
      tag_attrs = {id: 99, label: "ruby"}
      author_with_tag_attrs = {id: 10, name: "Alice", tag: tag_attrs}
      article_attrs = {id: 1, title: "Hello", author: author_with_tag_attrs}

      author_klass = author_with_tag_klass

      klass = Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :article

        collect_includes!

        identifier(:id) { resource[:id] }

        attribute(:title) { resource[:title] }

        relationship :author do
          author_klass.new(resource[:author])
        end
      end

      serializer = klass.new(article_attrs, include: {author: {tag: true}})
      result = serializer.render

      expect(result).to eq(
        article: {
          id: 1,
          title: "Hello",
          _type: "article",
          _relationships: {author: {id: 10, _type: "author"}}
        },
        included: [
          {id: 99, label: "ruby", _type: "tag"},
          {id: 10, name: "Alice", _type: "author", _relationships: {tag: {id: 99, _type: "tag"}}}
        ]
      )
    end
  end

  context "when a child has no identifier defined" do
    let :anon_klass do
      Class.new do
        include Halitosis

        attribute(:info) { "no id here" }
      end
    end

    it "falls back to inline rendering" do
      anon_klass = self.anon_klass

      klass = Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        collect_includes!

        resource :root

        identifier :id, value: 1

        relationship :anon do
          anon_klass.new
        end
      end

      serializer = klass.new(Object.new, include: {anon: true})
      result = serializer.render

      expect(result[:root][:_relationships][:anon]).to eq(info: "no id here")
      expect(result[:included]).to eq([])
    end
  end

  context "with an inline collection of resources with included relationships" do
    it "collects and deduplicates included relationships across all items" do
      serializer = Class.new do
        include Halitosis

        collect_includes!

        collection :articles do |articles|
          articles.map { |attrs|
            Class.new do
              include Halitosis
              include Halitosis::ResourceRelationships

              resource :article

              identifier(:id) { resource[:id] }
              attribute(:title) { resource[:title] }

              relationship :author do
                Class.new do
                  include Halitosis

                  resource :author

                  identifier(:id) { resource[:id] }
                  attribute(:name) { resource[:name] }
                end.new(resource[:author])
              end
            end.new(attrs)
          }
        end
      end.new(
        [
          {id: 1, title: "First", author: {id: 10, name: "Alice"}},
          {id: 2, title: "Second", author: {id: 10, name: "Alice"}}
        ],
        include: {author: true}
      )

      result = serializer.render

      expect(result).to eq(
        articles: [
          {id: 1, title: "First", _type: "article", _relationships: {author: {id: 10, _type: "author"}}},
          {id: 2, title: "Second", _type: "article", _relationships: {author: {id: 10, _type: "author"}}}
        ],
        included: [
          {id: 10, name: "Alice", _type: "author"}
        ]
      )
    end
  end

  context "with an array relationship" do
    it "stubs each item and hoists all into included, deduplicating" do
      author_klass = self.author_klass

      klass = Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :article

        collect_includes!

        identifier(:id) { resource[:id] }
        attribute(:title) { resource[:title] }

        relationship :authors do
          resource[:authors].map { |attrs| author_klass.new(attrs) }
        end
      end

      serializer = klass.new(
        {id: 1, title: "Hello", authors: [
          {id: 10, name: "Alice"},
          {id: 20, name: "Bob"},
          {id: 10, name: "Alice"}
        ]},
        include: {authors: true}
      )

      result = serializer.render

      expect(result).to eq(
        article: {
          id: 1,
          title: "Hello",
          _type: "article",
          _relationships: {
            authors: [
              {id: 10, _type: "author"},
              {id: 20, _type: "author"},
              {id: 10, _type: "author"}
            ]
          }
        },
        included: [
          {id: 10, name: "Alice", _type: "author"},
          {id: 20, name: "Bob", _type: "author"}
        ]
      )
    end
  end
end
