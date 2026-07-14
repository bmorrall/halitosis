# frozen_string_literal: true

RSpec.describe Halitosis::ResourceIncludeable do
  let(:authors_value) { [double("Author1"), double("Author2")] }

  let :klass do
    av = authors_value

    Class.new do
      include Halitosis

      resource :article

      # Stub relationships so include options flow through validate_relationships!.
      # In real applications these delegate to associated serializers.
      relationship(:authors) { av }
      relationship(:comments) { nil }
      relationship(:tags) { nil }
      relationship(:profile) { nil }
      relationship(:anything) { nil }
    end
  end

  describe ".allow_include" do
    context "with an arity-1 block" do
      it "adds a ResourceIncludeable::Field to the class fields" do
        klass.allow_include(:authors) { |_v| nil }

        fields = klass.fields.for_type(Halitosis::ResourceIncludeable::Field)
        expect(fields.size).to eq(1)
        expect(fields.first.name).to eq(:authors)
        expect(fields.first.path).to eq([:authors])
      end

      it "adds the path to fields" do
        klass.allow_include(:authors) { |_v| nil }

        expect(klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :authors)).not_to be_nil
      end

      it "returns nil" do
        result = klass.allow_include(:authors) { |_v| nil }
        expect(result).to be_nil
      end
    end

    context "without a block" do
      it "adds the path to fields as a nil-proc field without a preload" do
        klass.allow_include(:authors)

        field = klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :authors)
        expect(field).not_to be_nil
        expect(field.apply(klass.new(double), double)).to be_nil
      end

      it "returns nil" do
        expect(klass.allow_include(:authors)).to be_nil
      end
    end

    context "with an arity-0 namespace block" do
      it "registers the parent path as a nil-proc field in fields" do
        klass.allow_include(:authors) do
          preload ->(_v) {}
        end

        expect(klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :authors)).not_to be_nil
      end

      it "preload replaces the nil-proc declaration field, leaving exactly one field with a proc" do
        klass.allow_include(:authors) do
          preload ->(_v) {}
        end

        fields = klass.fields.for_type(Halitosis::ResourceIncludeable::Field)
        author_fields = fields.select { |f| f.path == [:authors] }
        expect(author_fields.size).to eq(1)

        serializer = klass.new(double("article"))
        expect(author_fields.first.apply(serializer, serializer.send(:build_context))).to be_nil
      end

      it "registers nested fields via allow_include inside the block" do
        klass.allow_include(:authors) do
          allow_include(:comments) { |_v| nil }
          allow_include(:tags) { |_v| nil }
        end

        fields = klass.fields.for_type(Halitosis::ResourceIncludeable::Field)
        expect(fields.map(&:name)).to contain_exactly(:authors, :"authors.comments", :"authors.tags")
        expect(fields.map(&:path)).to contain_exactly([:authors], [:authors, :comments], [:authors, :tags])
      end

      it "adds nested paths to fields" do
        klass.allow_include(:authors) do
          allow_include(:comments) { |_v| nil }
          allow_include(:tags) { |_v| nil }
        end

        expect(klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :authors)).not_to be_nil
        expect(klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :"authors.comments")).not_to be_nil
        expect(klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :"authors.tags")).not_to be_nil
      end

      it "registers a preload field alongside nested fields" do
        klass.allow_include(:authors) do
          preload ->(_v) {}
          allow_include(:comments) { |_v| nil }
        end

        fields = klass.fields.for_type(Halitosis::ResourceIncludeable::Field)
        expect(fields.map(&:name)).to contain_exactly(:authors, :"authors.comments")
      end

      it "allows a nested allow_include without a block" do
        klass.allow_include(:authors) do
          allow_include(:comments)
        end

        expect(klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :authors)).not_to be_nil
        expect(klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :"authors.comments")).not_to be_nil
      end

      it "raises InvalidField when a nested allow_include block has wrong arity" do
        expect do
          klass.allow_include(:authors) do
            allow_include(:comments) { |a, b| a }
          end
        end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*or 1 argument/i)
      end
    end

    it "raises InvalidField when the block accepts more than 1 argument" do
      expect do
        klass.allow_include(:authors) { |a, b| a }
      end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*or 1 argument/i)
    end
  end

  describe "ResourceIncludeable::Field#apply" do
    let(:article) { double("Article") }

    it "calls the block with nil when no preload: method is set on the relationship" do
      received_value = :not_called
      received_self = nil

      klass.allow_include(:authors) do |v|
        received_value = v
        received_self = self
        nil
      end

      serializer = klass.new(article)
      serializer.render(include: {authors: true})

      expect(received_value).to be_nil
      expect(received_self).to eq(serializer)
    end

    it "calls the block with the preload: method result and self as the serializer" do
      av = authors_value

      preload_klass = Class.new do
        include Halitosis

        resource :article

        define_method(:preload_authors) { av }

        relationship(:authors, preload: :preload_authors) { |preloaded = nil| preloaded || [] }
        relationship(:comments) { nil }
      end

      received_value = nil
      received_self = nil

      preload_klass.allow_include(:authors) do |v|
        received_value = v
        received_self = self
        nil
      end

      serializer = preload_klass.new(article)
      serializer.render(include: {authors: true})

      expect(received_value).to eq(authors_value)
      expect(received_self).to eq(serializer)
    end

    it "always returns nil regardless of the block return value" do
      klass.allow_include(:authors) { |_v| "something" }

      field = klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :authors)
      serializer = klass.new(article)

      expect(field.apply(serializer, serializer.send(:build_context))).to be_nil
    end

    it "stores the preloaded value in context under the relationship name" do
      preloaded = [double("PreloadedAuthor")]
      klass.allow_include(:authors) { |_v| preloaded }

      field = klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :authors)
      serializer = klass.new(article)
      context = serializer.send(:build_context)
      field.apply(serializer, context)

      expect(context.fetch_local(:resource_includeable_preloads)).to eq(authors: preloaded)
    end

    it "does not store anything in context when the block returns nil" do
      klass.allow_include(:authors) { |_v| nil }

      field = klass.fields.get_field(Halitosis::ResourceIncludeable::Field, :authors)
      serializer = klass.new(article)
      context = serializer.send(:build_context)
      field.apply(serializer, context)

      expect(context.fetch_local(:resource_includeable_preloads)).to be_nil
    end
  end

  describe "#apply_preloads!" do
    let(:article) { double("Article") }

    context "when no include options are present" do
      it "does not invoke any preload block" do
        invoked = false
        klass.allow_include(:authors) { |_v|
          invoked = true
          nil
        }

        klass.new(article).render
        expect(invoked).to be false
      end
    end

    context "when a matching include path is present" do
      it "calls the preload block with the relationship value" do
        received = nil
        klass.allow_include(:authors) { |v|
          received = v
          nil
        }

        klass.new(article).render(include: {authors: true})
        expect(received).to eq(authors_value)
      end
    end

    context "when walking leaf-up — deepest match wins" do
      it "fires authors.comments field and not the parent authors field when both declared" do
        fired = []
        klass.allow_include(:authors) do
          preload ->(_v) {
            fired << :authors
            nil
          }
          allow_include(:comments) { |_v|
            fired << :authors_comments
            nil
          }
        end

        klass.new(article).render(include: {authors: {comments: true}})
        expect(fired).to eq([:authors_comments])
      end

      it "falls back to parent field when no deeper field is declared" do
        fired = []
        klass.allow_include(:authors) { |_v|
          fired << :authors
          nil
        }

        klass.new(article).render(include: {authors: {profile: true}})
        expect(fired).to eq([:authors])
      end
    end

    context "with deduplication across sibling leaves" do
      it "fires the ancestor field only once when multiple siblings share it" do
        fired = []
        klass.allow_include(:authors) { |_v|
          fired << :authors
          nil
        }

        klass.new(article).render(include: {authors: {comments: true, tags: true}})
        expect(fired).to eq([:authors])
      end

      it "fires separate sibling fields each once" do
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
          allow_include(:tags) { |_v|
            fired << :tags
            nil
          }
        end

        klass.new(article).render(include: {authors: {comments: true, tags: true}})
        expect(fired).to contain_exactly(:comments, :tags)
      end
    end
  end

  describe "#validate_includes!" do
    let(:article) { double("Article") }

    context "when allow_undeclared_includes is false" do
      around do |example|
        original = Halitosis.config.allow_undeclared_includes
        Halitosis.config.allow_undeclared_includes = false
        example.run
      ensure
        Halitosis.config.allow_undeclared_includes = original
      end

      it "raises InvalidIncludeParameter for an undeclared top-level include" do
        klass.allow_include(:authors) { |_v| nil }

        expect {
          klass.new(article).render(include: {comments: true})
        }.to raise_error(Halitosis::InvalidIncludeParameter, /comments/)
      end

      it "raises for an undeclared nested path when only the parent is declared" do
        klass.allow_include(:authors) { |_v| nil }

        expect {
          klass.new(article).render(include: {authors: {comments: true}})
        }.to raise_error(Halitosis::InvalidIncludeParameter, /authors\.comments/)
      end

      it "does not raise when the exact nested path is declared" do
        klass.allow_include(:authors) do
          allow_include(:comments) { |_v| nil }
        end

        expect {
          klass.new(article).render(include: {authors: {comments: true}})
        }.not_to raise_error
      end

      it "does not raise for a declaration-only path with no preload block" do
        klass.allow_include(:authors)

        expect {
          klass.new(article).render(include: {authors: true})
        }.not_to raise_error
      end

      it "does not validate when no allow_include declarations exist" do
        expect {
          klass.new(article).render(include: {anything: true})
        }.not_to raise_error
      end

      it "includes 'resource' in the error message" do
        klass.allow_include(:authors)

        expect {
          klass.new(article).render(include: {comments: true})
        }.to raise_error(Halitosis::InvalidIncludeParameter, /article resource/)
      end
    end

    context "when allow_undeclared_includes is true (default)" do
      it "does not raise for undeclared include paths" do
        klass.allow_include(:authors) { |_v| nil }

        expect {
          klass.new(article).render(include: {comments: true})
        }.not_to raise_error
      end
    end
  end
end
