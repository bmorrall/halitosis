# frozen_string_literal: true

RSpec.describe Halitosis::CollectionIncludeable do
  let :klass do
    Class.new do
      include Halitosis

      collection :items do |collection|
        collection.map { |i| i }
      end
    end
  end

  describe ".allow_include" do
    context "with an arity-1 block" do
      it "adds a CollectionIncludeable::Field to the class fields" do
        klass.allow_include(:author) { |coll| coll }

        fields = klass.fields.for_type(Halitosis::CollectionIncludeable::Field)
        expect(fields.size).to eq(1)
        expect(fields.first.name).to eq(:author)
        expect(fields.first.path).to eq([:author])
      end

      it "adds the path to fields as a nil-proc field" do
        klass.allow_include(:author) { |coll| coll }

        expect(klass.fields.get_field(Halitosis::CollectionIncludeable::Field, :author)).not_to be_nil
      end

      it "returns nil" do
        result = klass.allow_include(:author) { |coll| coll }
        expect(result).to be_nil
      end
    end

    context "without a block" do
      it "adds the path to fields as a pass-through field without a preload" do
        klass.allow_include(:author)

        field = klass.fields.get_field(Halitosis::CollectionIncludeable::Field, :author)
        expect(field).not_to be_nil

        ctx = instance_double(Halitosis::CollectionContext, collection: [1, 2, 3])
        allow(ctx).to receive(:call_instance_with).with([1, 2, 3], Halitosis::CollectionIncludeable::Field::DEFAULT_PROCEDURE).and_return([1, 2, 3])
        expect(field.apply(ctx)).to eq([1, 2, 3])
      end

      it "returns nil" do
        expect(klass.allow_include(:author)).to be_nil
      end
    end

    context "with an arity-0 namespace block" do
      it "registers the parent path as a nil-proc field in fields" do
        klass.allow_include(:author) do
          preload ->(coll) { coll }
        end

        expect(klass.fields.get_field(Halitosis::CollectionIncludeable::Field, :author)).not_to be_nil
      end

      it "preload replaces the nil-proc declaration field, leaving exactly one field with a proc" do
        klass.allow_include(:author) do
          preload ->(coll) { coll }
        end

        fields = klass.fields.for_type(Halitosis::CollectionIncludeable::Field)
        author_fields = fields.select { |f| f.path == [:author] }
        expect(author_fields.size).to eq(1)
        ctx = Halitosis::CollectionContext.new(klass.new([]), {})
        ctx.collection = [1]
        expect(author_fields.first.apply(ctx)).not_to be_nil
      end

      it "registers a field at the top level when preload is called" do
        klass.allow_include(:author) do
          preload ->(coll) { coll }
        end

        fields = klass.fields.for_type(Halitosis::CollectionIncludeable::Field)
        expect(fields.map { |f| f.path }).to include([:author])
      end

      it "registers nested fields via allow_include inside the block" do
        klass.allow_include(:author) do
          allow_include(:avatar) { |coll| coll }
          allow_include(:summary) { |coll| coll }
        end

        fields = klass.fields.for_type(Halitosis::CollectionIncludeable::Field)
        expect(fields.map(&:name)).to contain_exactly(:author, :"author.avatar", :"author.summary")
        expect(fields.map(&:path)).to contain_exactly([:author], [:author, :avatar], [:author, :summary])
      end

      it "adds nested paths to fields" do
        klass.allow_include(:author) do
          allow_include(:avatar) { |coll| coll }
          allow_include(:summary) { |coll| coll }
        end

        expect(klass.fields.get_field(Halitosis::CollectionIncludeable::Field, :author)).not_to be_nil
        expect(klass.fields.get_field(Halitosis::CollectionIncludeable::Field, :"author.avatar")).not_to be_nil
        expect(klass.fields.get_field(Halitosis::CollectionIncludeable::Field, :"author.summary")).not_to be_nil
      end

      it "registers a preload field alongside nested fields" do
        klass.allow_include(:author) do
          preload ->(coll) { coll }
          allow_include(:avatar) { |coll| coll }
        end

        fields = klass.fields.for_type(Halitosis::CollectionIncludeable::Field)
        expect(fields.map(&:name)).to contain_exactly(:author, :"author.avatar")
      end

      it "supports a nested arity-0 namespace block inside the outer namespace" do
        klass.allow_include(:author) do
          allow_include(:publications) do
            preload ->(coll) { coll }
          end
        end

        fields = klass.fields.for_type(Halitosis::CollectionIncludeable::Field)
        expect(fields.map(&:path)).to include([:author, :publications])
      end

      it "allows a nested allow_include without a block" do
        klass.allow_include(:author) do
          allow_include(:avatar)
        end

        expect(klass.fields.get_field(Halitosis::CollectionIncludeable::Field, :author)).not_to be_nil
        expect(klass.fields.get_field(Halitosis::CollectionIncludeable::Field, :"author.avatar")).not_to be_nil
      end

      it "raises InvalidField when a nested allow_include block has wrong arity" do
        expect do
          klass.allow_include(:author) do
            allow_include(:avatar) { |a, b| a }
          end
        end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*or 1 argument/i)
      end
    end

    it "raises InvalidField when the block accepts more than 1 argument" do
      expect do
        klass.allow_include(:author) { |a, b| a }
      end.to raise_error(Halitosis::InvalidField, /must accept 0 arguments.*or 1 argument/i)
    end

    context "with nested paths via namespace block" do
      it "registers parent and child fields via preload + allow_include" do
        klass.allow_include(:author) do
          preload ->(coll) { coll }
          allow_include(:avatar) { |coll| coll }
        end

        fields = klass.fields.for_type(Halitosis::CollectionIncludeable::Field)
        expect(fields.map(&:name)).to contain_exactly(:author, :"author.avatar")
        expect(fields.map(&:path)).to contain_exactly([:author], [:author, :avatar])
      end
    end
  end

  describe "CollectionIncludeable::Field#apply" do
    let(:items) { [1, 2, 3] }

    it "calls the block with the current collection and self as the serializer" do
      received_coll = nil
      received_self = nil

      klass.allow_include(:author) do |coll|
        received_coll = coll
        received_self = self
        coll
      end

      serializer = klass.new(items)
      serializer.render(include: {author: true})

      expect(received_coll).to eq(items)
      expect(received_self).to eq(serializer)
    end
  end

  describe "#apply_preloads!" do
    let(:items) { [1, 2, 3] }

    context "when no include options are present" do
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

    context "when a matching include path is present" do
      it "applies the preload block and updates the collection" do
        doubled = nil
        klass.allow_include(:author) { |coll| doubled = coll + coll }

        klass.new(items).render(include: {author: true})
        expect(doubled).to eq(items + items)
      end
    end

    context "with nil return from block" do
      it "leaves the collection unchanged" do
        klass.allow_include(:author) { |_coll| nil }

        serializer = klass.new(items)
        serializer.render(include: {author: true})

        expect(serializer.raw_collection).to eq(items)
      end
    end

    context "when walking leaf-up — deepest match wins" do
      it "fires author.avatar field and not the parent author field when both declared" do
        fired = []
        klass.allow_include(:author) do
          preload ->(coll) {
            fired << :author
            coll
          }
          allow_include(:avatar) { |coll|
            fired << :author_avatar
            coll
          }
        end

        klass.new(items).render(include: {author: {avatar: true}})
        expect(fired).to eq([:author_avatar])
      end

      it "falls back to parent field when no deeper field is declared" do
        fired = []
        klass.allow_include(:author) { |coll|
          fired << :author
          coll
        }

        klass.new(items).render(include: {author: {profile: true}})
        expect(fired).to eq([:author])
      end
    end

    context "with deduplication across sibling leaves" do
      it "fires the ancestor field only once when multiple siblings share it" do
        fired = []
        klass.allow_include(:author) { |coll|
          fired << :author
          coll
        }

        klass.new(items).render(include: {author: {avatar: true, summary: true}})
        expect(fired).to eq([:author])
      end

      it "fires separate sibling fields each once" do
        fired = []
        klass.allow_include(:author) do
          preload ->(coll) {
            fired << :author
            coll
          }
          allow_include(:avatar) { |coll|
            fired << :avatar
            coll
          }
          allow_include(:summary) { |coll|
            fired << :summary
            coll
          }
        end

        klass.new(items).render(include: {author: {avatar: true, summary: true}})
        expect(fired).to contain_exactly(:avatar, :summary)
      end
    end

    context "when include path does not match any field" do
      it "does not raise and leaves the collection unchanged" do
        klass.allow_include(:author) { |coll| coll + coll }

        serializer = klass.new(items)
        expect { serializer.render(include: {comments: true}) }.not_to raise_error
        expect(serializer.raw_collection).to eq(items)
      end
    end
  end

  describe "#validate_includes!" do
    let(:items) { [1, 2, 3] }

    context "when allow_undeclared_includes is false" do
      around do |example|
        original = Halitosis.config.allow_undeclared_includes
        Halitosis.config.allow_undeclared_includes = false
        example.run
      ensure
        Halitosis.config.allow_undeclared_includes = original
      end

      it "raises InvalidIncludeParameter for an undeclared top-level include" do
        klass.allow_include(:author) { |coll| coll }

        expect {
          klass.new(items).render(include: {comments: true})
        }.to raise_error(Halitosis::InvalidIncludeParameter, /comments/)
      end

      it "raises for an undeclared nested path when only the parent is declared" do
        klass.allow_include(:author) { |coll| coll }

        expect {
          klass.new(items).render(include: {author: {avatar: true}})
        }.to raise_error(Halitosis::InvalidIncludeParameter, /author\.avatar/)
      end

      it "does not raise when the exact nested path is declared" do
        klass.allow_include(:author) do
          allow_include(:avatar) { |coll| coll }
        end

        expect {
          klass.new(items).render(include: {author: {avatar: true}})
        }.not_to raise_error
      end

      it "does not raise for a declaration-only path with no preload block" do
        klass.allow_include(:author)

        expect {
          klass.new(items).render(include: {author: true})
        }.not_to raise_error
      end

      it "does not validate when no allow_include declarations exist" do
        expect {
          klass.new(items).render(include: {anything: true})
        }.not_to raise_error
      end
    end

    context "when allow_undeclared_includes is true (default)" do
      it "does not raise for undeclared include paths" do
        klass.allow_include(:author) { |coll| coll }

        expect {
          klass.new(items).render(include: {comments: true})
        }.not_to raise_error
      end
    end
  end
end
