# frozen_string_literal: true

RSpec.describe Halitosis::Links do
  let :klass do
    Class.new { include Halitosis }
  end

  describe Halitosis::Links::ClassMethods do
    describe "#link" do
      describe "with procedure" do
        it "builds simple field" do
          link = klass.link(:self) { "path" }

          expect(link.name).to eq(:self)
          expect(link.options).to eq(attrs: {})
          expect(link.procedure.call).to eq("path")
        end

        it "builds complex field" do
          link = klass.link(
            :self, :templated, foo: "foo", attrs: {bar: "bar"}
          ) { "path" }

          expect(link.name).to eq(:self)
          expect(link.options).to eq(
            foo: "foo", attrs: {templated: true, bar: "bar"}
          )
          expect(link.procedure.call).to eq("path")
        end

        it "handles multiple values" do
          klass.link(:self) { %w[foo bar] }

          rendered = klass.new.render[:_links][:self]

          expect(rendered).to eq([{href: "foo"}, {href: "bar"}])
        end
      end

      describe "without procedure" do
        describe "with explicit value" do
          it "builds simple field" do
            link = klass.link(:self, value: "path")

            expect(link.name).to eq(:self)
            expect(link.options).to eq(attrs: {}, value: "path")
            expect(link.procedure).to be_nil
          end

          it "builds complex field" do
            link = klass.link(
              :self,
              :templated,
              foo: "foo", attrs: {bar: "bar"}, value: "path"
            )

            expect(link.name).to eq(:self)
            expect(link.options).to eq(
              foo: "foo",
              attrs: {templated: true, bar: "bar"},
              value: "path"
            )
            expect(link.procedure).to be_nil
          end
        end
      end

      it "converts string rel to symbol" do
        link = klass.link("ea:find", value: "path")

        expect(link.name).to eq(:"ea:find")
      end
    end
  end

  describe Halitosis::Links::InstanceMethods do
    describe "options[:include_links]" do
      let :klass do
        Class.new do
          include Halitosis
        end
      end

      it "includes links when true" do
        klass.link(:self, :templated, foo: "foo", attrs: {bar: "bar"}) { "path" }
        serializer = klass.new("include_links" => true)

        expect(serializer.options).to eq({include_links: true})
        render = serializer.render

        expect(render[:_links]).to eq(self: {bar: "bar", href: "path", templated: true})
      end

      it "defaults to true" do
        klass.link(:self, :templated, foo: "foo", attrs: {bar: "bar"}) { "path" }
        serializer = klass.new
        render = serializer.render

        expect(render[:_links]).to eq(self: {bar: "bar", href: "path", templated: true})
      end

      it "excludes links when false" do
        klass.link(:self, :templated, foo: "foo", attrs: {bar: "bar"}) { "path" }
        serializer = klass.new("include_links" => false)
        expect(serializer.options).to eq({include_links: false})

        render = serializer.render

        expect(render[:_links]).to eq(nil)
      end
    end

    describe "#links" do
      let :klass do
        Class.new do
          include Halitosis

          link(:self) { nil }
        end
      end

      it "does not include link if value is nil" do
        serializer = klass.new

        expect(serializer.links).to eq({})
      end
    end
  end
end
