# frozen_string_literal: true

RSpec.describe Halitosis::ResourceIncludes do
  let :klass do
    Class.new do
      include Halitosis::Base
      include Halitosis::Preloadable
      include Halitosis::ResourceRelationships
      include Halitosis::ResourceIncludes
    end
  end

  describe Halitosis::ResourceIncludes::ClassMethods do
    describe "#allow_include" do
      it "adds a ResourceIncludes::Field to fields" do
        expect(klass.fields).to receive(:add).with(kind_of(Halitosis::ResourceIncludes::Field)).and_call_original

        klass.allow_include(:accounts) {}
      end

      it "does not register a preload" do
        klass.allow_include(:accounts) {}

        expect(klass.preload_registered?(:accounts)).to be(false)
      end

      it "stores the field with the correct name" do
        klass.allow_include(:accounts) {}

        field = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first

        expect(field.name).to eq(:accounts)
      end

      it "stores children declared inside the builder block" do
        klass.allow_include(:accounts) do
          allow_include(:owner) { |v| v }
        end

        field = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first

        expect(field.children.map(&:name)).to eq([:owner])
      end

      it "stores nested children recursively" do
        klass.allow_include(:accounts) do
          allow_include :owner do
            allow_include(:avatar) { |v| v }
          end
        end

        root = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first
        owner = root.children.first

        expect(owner.children.map(&:name)).to eq([:avatar])
      end

      it "assigns the arity-1 block as the procedure for a leaf child" do
        proc = ->(v) { v }
        klass.allow_include(:accounts) do
          allow_include(:owner, &proc)
        end

        leaf = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first.children.first

        expect(leaf.procedure).to eq(proc)
      end

      it "assigns the preload procedure for a builder child" do
        preload_proc = ->(v) { v.reverse }
        klass.allow_include(:accounts) do
          allow_include(:owner) do
            preload preload_proc
          end
        end

        child = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first.children.first

        expect(child.procedure).to eq(preload_proc)
      end

      it "uses nil procedure for a builder child without a preload call" do
        klass.allow_include(:accounts) do
          allow_include(:owner) {}
        end

        child = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first.children.first

        expect(child.procedure).to be_nil
      end

      it "uses nil procedure for a leaf child declared without a block" do
        klass.allow_include(:accounts) do
          allow_include(:owner)
        end

        child = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first.children.first

        expect(child.procedure).to be_nil
      end

      it "builds an empty field when called without a block" do
        klass.allow_include(:accounts)

        field = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first

        expect(field.name).to eq(:accounts)
        expect(field.children).to be_empty
      end

      it "stores the arity-1 block as the procedure on a leaf field" do
        proc = ->(v) { v }
        klass.allow_include(:accounts, &proc)

        field = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first

        expect(field.procedure).to eq(proc)
        expect(field.children).to be_empty
      end
    end
  end

  describe Halitosis::ResourceIncludes::InstanceMethods do
    before do
      klass.relationship(:items, preload: :items_data) { |items| items }

      klass.allow_include(:items) do
        allow_include(:detail) { |items| items&.map { |i| "#{i}:detail" } }
        allow_include(:summary) { |items| items&.map { |i| "#{i}:summary" } }
      end

      klass.define_method(:items_data) { %w[a b c] }
    end

    let(:serializer) { klass.new(include: include_param) }
    let(:context) { serializer.send(:build_context) }

    describe "#before_render" do
      context "when no nested include is requested" do
        let(:include_param) { "items" }

        it "does not modify the cached preload value" do
          serializer.before_render(context)

          expect(context.fetch_local(:preloaded)[:items]).to eq(%w[a b c])
        end
      end

      context "when include=items.detail is requested" do
        let(:include_param) { "items.detail" }

        it "applies the :detail procedure to the cached value" do
          serializer.before_render(context)

          expect(context.fetch_local(:preloaded)[:items]).to eq(%w[a:detail b:detail c:detail])
        end
      end

      context "when include=items.summary is requested" do
        let(:include_param) { "items.summary" }

        it "applies the :summary procedure to the cached value" do
          serializer.before_render(context)

          expect(context.fetch_local(:preloaded)[:items]).to eq(%w[a:summary b:summary c:summary])
        end
      end

      context "when the relationship is not preloaded (no preload: option declared)" do
        before do
          klass.relationship(:blocked) { nil }
          klass.define_method(:blocked) { nil }
          klass.allow_include(:blocked) do
            allow_include(:detail) { |v| v }
          end
        end

        let(:include_param) { "blocked.detail" }

        it "raises ArgumentError because :blocked has not been preloaded" do
          expect { serializer.before_render(context) }.to raise_error(
            ArgumentError,
            /allow_include :blocked.*not been preloaded/
          )
        end
      end

      context "when the relationship is not enabled in the current context" do
        let(:include_param) { "other" }

        it "does not modify the cached preload value for items" do
          serializer.before_render(context)

          expect(context.fetch_local(:preloaded)).to be_nil
        end
      end

      context "when the preloaded value is nil" do
        before do
          klass.define_method(:items_data) { nil }
        end

        let(:include_param) { "items.detail" }

        it "does not apply the include procedure and leaves the cache as nil" do
          serializer.before_render(context)

          expect(context.fetch_local(:preloaded)[:items]).to be_nil
        end
      end

      context "when the requested path has no matching allow_include child" do
        let(:include_param) { "items.unknown" }

        it "does not raise and leaves the cached value unchanged" do
          serializer.before_render(context)

          expect(context.fetch_local(:preloaded)[:items]).to eq(%w[a b c])
        end
      end

      context "when allow_include is declared for a name with no matching relationship field" do
        before do
          klass.allow_include(:orphan) do
            allow_include(:child) { |v| v }
          end
        end

        let(:include_param) { "orphan.child" }

        it "raises ArgumentError because :orphan has not been preloaded" do
          expect { serializer.before_render(context) }.to raise_error(
            ArgumentError,
            /allow_include :orphan.*not been preloaded/
          )
        end
      end

      context "when the relationship has an :if guard that returns false" do
        before do
          klass.relationship(:guarded, preload: :guarded_data, if: :show_guarded?) { |v| v }
          klass.allow_include(:guarded) do
            allow_include(:child) { |v| v }
          end
          klass.define_method(:guarded_data) { %w[x y] }
          klass.define_method(:show_guarded?) { false }
        end

        let(:include_param) { "guarded.child" }

        it "silently skips because the preload was suppressed by the guard" do
          expect { serializer.before_render(context) }.not_to raise_error
        end
      end

      context "with three levels of nesting (items.detail.meta)" do
        before do
          klass.allow_include(:items) do
            allow_include(:detail) do
              allow_include(:meta) { |items| items.map { |i| "#{i}:meta" } }
            end
          end
        end

        let(:include_param) { "items.detail.meta" }

        it "applies the deepest procedure" do
          serializer.before_render(context)

          expect(context.fetch_local(:preloaded)[:items]).to eq(%w[a:meta b:meta c:meta])
        end
      end

      context "when allow_include is declared with an arity-1 leaf procedure" do
        before do
          klass.relationship(:enriched, preload: :enriched_data) { |items| items }
          klass.allow_include(:enriched) { |items| items.map { |i| "#{i}:enriched" } }
          klass.define_method(:enriched_data) { %w[x y z] }
        end

        context "when the relationship is included" do
          let(:include_param) { "enriched" }

          it "applies the leaf procedure to the cached preload value" do
            s = klass.new(include: include_param)
            ctx = s.send(:build_context)
            s.before_render(ctx)

            expect(ctx.fetch_local(:preloaded)[:enriched]).to eq(%w[x:enriched y:enriched z:enriched])
          end
        end

        context "when the relationship is not included" do
          let(:include_param) { "other" }

          it "does not modify the cache" do
            s = klass.new(include: include_param)
            ctx = s.send(:build_context)
            s.before_render(ctx)

            expect(ctx.fetch_local(:preloaded)).to be_nil
          end
        end

        context "when the serializer is embedded (non-root)" do
          it "does not apply the leaf procedure" do
            parent_klass = Class.new { include Halitosis::Base }
            parent_ctx = parent_klass.new.send(:build_context)

            s = klass.new(include: "enriched")
            ctx = s.send(:build_context, parent: parent_ctx)

            expect(ctx.root?).to be(false)

            s.before_render(ctx)

            expect(ctx.fetch_local(:preloaded)[:enriched]).to eq(%w[x y z])
          end
        end
      end
    end
  end
end
