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
        _relationships: {author: {id: 10, _type: "author"}}
      )

      expect(result[:_included]).to eq(
        author: [{id: 10, name: "Alice"}]
      )
    end

    it "does not add included key when no relationships are included" do
      serializer = article_klass.new(article_attrs)

      result = serializer.render
      expect(result).not_to have_key(:_included)
    end
  end

  context "with multiple articles referencing the same author" do
    let :collection_klass do
      article_klass = self.article_klass

      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

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

      expect(result[:_included]).to eq(author: [{id: 10, name: "Alice"}])
    end

    it "includes each distinct author once" do
      bob_attrs = {id: 20, name: "Bob"}
      articles = [
        {id: 1, title: "First", author: author_attrs},
        {id: 2, title: "Second", author: bob_attrs}
      ]

      serializer = collection_klass.new(articles, include: {author: true})
      result = serializer.render

      expect(result[:_included]).to eq(
        author: [
          {id: 10, name: "Alice"},
          {id: 20, name: "Bob"}
        ]
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
          _relationships: {author: {id: 10, _type: "author"}}
        },
        _included: {
          tag: [{id: 99, label: "ruby"}],
          author: [{id: 10, name: "Alice", _relationships: {tag: {id: 99, _type: "tag"}}}]
        }
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

        resource :root

        identifier :id, value: 1

        relationship :anon do
          anon_klass.new
        end
      end

      serializer = klass.new(Object.new, include: {anon: true})
      result = serializer.render

      expect(result[:root][:_relationships][:anon]).to eq(info: "no id here")
      expect(result[:_included]).to eq({})
    end
  end

  context "with an inline collection of resources with included relationships" do
    it "collects and deduplicates included relationships across all items" do
      serializer = Class.new do
        include Halitosis

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
          {id: 1, title: "First", _relationships: {author: {id: 10, _type: "author"}}},
          {id: 2, title: "Second", _relationships: {author: {id: 10, _type: "author"}}}
        ],
        _included: {
          author: [{id: 10, name: "Alice"}]
        }
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
          _relationships: {
            authors: [
              {id: 10, _type: "author"},
              {id: 20, _type: "author"},
              {id: 10, _type: "author"}
            ]
          }
        },
        _included: {
          author: [
            {id: 10, name: "Alice"},
            {id: 20, name: "Bob"}
          ]
        }
      )
    end
  end

  context "with legacy_nesting!" do
    let :author_with_tag_klass do
      tag_klass = Class.new do
        include Halitosis

        resource :tag

        identifier(:id) { resource[:id] }

        attribute(:label) { resource[:label] }
      end

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

    let :legacy_article_klass do
      author_klass = author_with_tag_klass

      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :article

        legacy_nesting!

        identifier(:id) { resource[:id] }

        attribute(:title) { resource[:title] }

        relationship :author do
          author_klass.new(resource[:author])
        end

        relationship :authors do
          resource[:authors].map { |attrs| author_klass.new(attrs) }
        end
      end
    end

    let(:author_with_tag_attrs) { {id: 10, name: "Alice", tag: {id: 99, label: "ruby"}} }

    it "nests the full payload of each depth inline with a _type" do
      serializer = legacy_article_klass.new(
        {id: 1, title: "Hello", author: author_with_tag_attrs},
        include: {author: {tag: true}}
      )

      expect(serializer.render).to eq(
        article: {
          id: 1,
          title: "Hello",
          _relationships: {
            author: {
              id: 10,
              _type: "author",
              name: "Alice",
              _relationships: {tag: {id: 99, _type: "tag", label: "ruby"}}
            }
          }
        }
      )
    end

    it "nests every item of an array relationship without deduplicating" do
      serializer = legacy_article_klass.new(
        {id: 1, title: "Hello", authors: [author_with_tag_attrs, author_with_tag_attrs]},
        include: {authors: true}
      )

      expect(serializer.render).to eq(
        article: {
          id: 1,
          title: "Hello",
          _relationships: {
            authors: [
              {id: 10, _type: "author", name: "Alice"},
              {id: 10, _type: "author", name: "Alice"}
            ]
          }
        }
      )
    end

    it "applies to a collection root, leaving primary items without a _type" do
      article_klass = Class.new(legacy_article_klass)

      collection_klass = Class.new do
        include Halitosis

        legacy_nesting!

        collection :articles do |articles|
          articles.map { |attrs| article_klass.new(attrs) }
        end
      end

      serializer = collection_klass.new(
        [{id: 1, title: "First", author: author_with_tag_attrs}],
        include: {author: true}
      )

      expect(serializer.render).to eq(
        articles: [
          {id: 1, title: "First", _relationships: {author: {id: 10, _type: "author", name: "Alice"}}}
        ]
      )
    end

    it "is decided by the root serializer" do
      article_klass = legacy_article_klass

      collection_klass = Class.new do
        include Halitosis

        collection :articles do |articles|
          articles.map { |attrs| article_klass.new(attrs) }
        end
      end

      serializer = collection_klass.new(
        [{id: 1, title: "First", author: author_with_tag_attrs}],
        include: {author: true}
      )

      expect(serializer.render).to eq(
        articles: [
          {id: 1, title: "First", _relationships: {author: {id: 10, _type: "author"}}}
        ],
        _included: {
          author: [{id: 10, name: "Alice"}]
        }
      )
    end
  end

  context "when the same resource is reached by include paths requesting different relationships" do
    let :graph_klass do
      leaf = ->(name) do
        Class.new do
          include Halitosis

          resource name

          identifier(:id) { resource[:id] }
        end
      end
      c_klass = leaf.call(:c)
      e_klass = leaf.call(:e)

      b_klass = Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :b

        identifier(:id) { resource[:id] }

        relationship(:c) { c_klass.new({id: 3}) }
        relationship(:e) { e_klass.new({id: 5}) }
      end

      d_klass = Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :d

        identifier(:id) { resource[:id] }

        relationship(:b) { b_klass.new({id: resource[:b_id]}) }
      end

      Class.new do
        include Halitosis
        include Halitosis::ResourceRelationships

        resource :a

        identifier(:id) { resource[:id] }

        relationship(:b) { b_klass.new({id: 2}) }
        relationship(:d) { d_klass.new({id: 4, b_id: resource[:d_b_id]}) }
      end
    end

    it "merges the relationships requested by every path into the shared payload" do
      result = graph_klass.new({id: 1, d_b_id: 2}, include: "b.c,d.b.e").render

      expect(result[:_included]).to eq(
        c: [{id: 3}],
        b: [{id: 2, _relationships: {c: {id: 3, _type: "c"}, e: {id: 5, _type: "e"}}}],
        e: [{id: 5}],
        d: [{id: 4, _relationships: {b: {id: 2, _type: "b"}}}]
      )
    end

    it "merges regardless of the order the include paths are given in" do
      result = graph_klass.new({id: 1, d_b_id: 2}, include: "d.b.e,b.c").render

      expect(result[:_included][:b]).to eq(
        [{id: 2, _relationships: {c: {id: 3, _type: "c"}, e: {id: 5, _type: "e"}}}]
      )
      expect(result[:_included][:e]).to eq([{id: 5}])
    end

    it "keeps separate payloads for different records of the same type" do
      result = graph_klass.new({id: 1, d_b_id: 6}, include: "b.c,d.b.e").render

      expect(result[:_included][:b]).to eq(
        [
          {id: 2, _relationships: {c: {id: 3, _type: "c"}}},
          {id: 6, _relationships: {e: {id: 5, _type: "e"}}}
        ]
      )
    end
  end
end
