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

      it "uses DEFAULT_PROCEDURE for a builder child without a preload call" do
        klass.allow_include(:accounts) do
          allow_include(:owner) {}
        end

        child = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first.children.first

        expect(child.procedure).to eq(Halitosis::ResourceIncludes::Field::DEFAULT_PROCEDURE)
      end

      it "uses DEFAULT_PROCEDURE for a leaf child declared without a block" do
        klass.allow_include(:accounts) do
          allow_include(:owner)
        end

        child = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first.children.first

        expect(child.procedure).to eq(Halitosis::ResourceIncludes::Field::DEFAULT_PROCEDURE)
      end

      it "builds an empty field when called without a block" do
        klass.allow_include(:accounts)

        field = klass.fields.for_type(Halitosis::ResourceIncludes::Field).first

        expect(field.name).to eq(:accounts)
        expect(field.children).to be_empty
      end
    end
  end

  describe Halitosis::ResourceIncludes::InstanceMethods do
    before do
      klass.relationship(:items, preload: :items_data) { |items| items }

      klass.allow_include(:items) do
        allow_include(:detail) { |items| items.map { |i| "#{i}:detail" } }
        allow_include(:summary) { |items| items.map { |i| "#{i}:summary" } }
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

          expect(context.fetch_local(:includeable_preloads)[:items]).to eq(%w[a b c])
        end
      end

      context "when include=items.detail is requested" do
        let(:include_param) { "items.detail" }

        it "applies the :detail procedure to the cached value" do
          serializer.before_render(context)

          expect(context.fetch_local(:includeable_preloads)[:items]).to eq(%w[a:detail b:detail c:detail])
        end
      end

      context "when include=items.summary is requested" do
        let(:include_param) { "items.summary" }

        it "applies the :summary procedure to the cached value" do
          serializer.before_render(context)

          expect(context.fetch_local(:includeable_preloads)[:items]).to eq(%w[a:summary b:summary c:summary])
        end
      end

      context "when the relationship has no preload key" do
        before do
          klass.relationship(:blocked) { nil }
          klass.allow_include(:blocked) do
            allow_include(:detail) { |v| raise "should not be called" }
          end
        end

        let(:include_param) { "blocked.detail" }

        it "skips processing for that relationship" do
          expect { serializer.before_render(context) }.not_to raise_error
        end
      end

      context "when the relationship is not enabled in the current context" do
        let(:include_param) { "other" }

        it "does not modify the cached preload value for items" do
          serializer.before_render(context)

          expect(context.fetch_local(:includeable_preloads)).to be_nil
        end
      end

      context "when the preloaded value is nil" do
        before do
          klass.define_method(:items_data) { nil }
        end

        let(:include_param) { "items.detail" }

        it "does not apply the include procedure" do
          serializer.before_render(context)

          expect(context.fetch_local(:includeable_preloads)[:items]).to be_nil
        end
      end

      context "when the requested path has no matching allow_include child" do
        let(:include_param) { "items.unknown" }

        it "does not raise and leaves the cached value unchanged" do
          serializer.before_render(context)

          expect(context.fetch_local(:includeable_preloads)[:items]).to eq(%w[a b c])
        end
      end

      context "when allow_include is declared for a name with no matching relationship field" do
        before do
          klass.allow_include(:orphan) do
            allow_include(:child) { |v| v }
          end
        end

        let(:include_param) { "orphan.child" }

        it "skips the allow_include field gracefully" do
          expect { serializer.before_render(context) }.not_to raise_error
        end
      end

      context "when the relationship has an :if guard that returns false" do
        before do
          klass.relationship(:guarded, preload: :guarded_data, if: :show_guarded?) { |v| v }
          klass.allow_include(:guarded) do
            allow_include(:child) { |v| raise "should not be called" }
          end
          klass.define_method(:guarded_data) { %w[x y] }
          klass.define_method(:show_guarded?) { false }
        end

        let(:include_param) { "guarded.child" }

        it "skips processing for the disabled relationship" do
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

          expect(context.fetch_local(:includeable_preloads)[:items]).to eq(%w[a:meta b:meta c:meta])
        end
      end
    end

    describe "#validate_includes!" do
      context "when allow_undeclared_includes is false" do
        around do |example|
          original = Halitosis.config.allow_undeclared_includes
          Halitosis.config.allow_undeclared_includes = false
          example.run
        ensure
          Halitosis.config.allow_undeclared_includes = original
        end

        it "raises InvalidIncludeParameter for an undeclared nested path" do
          expect {
            klass.new(include: "items.unknown").render
          }.to raise_error(Halitosis::InvalidIncludeParameter, /items\.unknown/)
        end

        it "raises for an undeclared top-level path when allow_include declarations exist" do
          expect {
            klass.new(include: "unknown").render
          }.to raise_error(Halitosis::InvalidIncludeParameter, /unknown/)
        end

        it "does not raise for a declared nested path" do
          expect {
            klass.new(include: "items.detail").render
          }.not_to raise_error
        end

        it "does not raise for the declared top-level path with no nesting" do
          expect {
            klass.new(include: "items").render
          }.not_to raise_error
        end

        it "does not validate when no allow_include declarations exist" do
          bare_klass = Class.new do
            include Halitosis::Base
            include Halitosis::Preloadable
            include Halitosis::ResourceRelationships
            include Halitosis::ResourceIncludes

            relationship(:anything) { nil }
          end

          expect {
            bare_klass.new(include: "anything").render
          }.not_to raise_error
        end
      end

      context "when allow_undeclared_includes is true (default)" do
        it "does not raise for undeclared paths" do
          expect {
            klass.new(include: "items.unknown").render
          }.not_to raise_error
        end
      end
    end
  end
end
