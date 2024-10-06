# frozen_string_literal: true

RSpec.describe Halitosis::Links do
  let :klass do
    Class.new {
      include Halitosis::Base
      include Halitosis::Links
    }
  end

  describe Halitosis::Links::ClassMethods do
    describe "#link" do
      describe "with procedure" do
        it "builds simple field" do
          link = klass.link(:self) { "path" }

          expect(link.name).to eq(:self)
          expect(link.options).to eq(attrs: {})
          expect(link.send(:procedure).call).to eq("path")
        end

        it "builds complex field" do
          link = klass.link(
            :self, :templated, foo: "foo", attrs: {bar: "bar"}
          ) { "path" }

          expect(link.name).to eq(:self)
          expect(link.options).to eq(
            foo: "foo", attrs: {templated: true, bar: "bar"}
          )
          expect(link.send(:procedure).call).to eq("path")
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
            expect(link.send(:procedure)).to be_nil
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
            expect(link.send(:procedure)).to be_nil
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
    describe "#render" do
      let :rendered do
        klass.new(include_root: false).render
      end

      it "renders simple link" do
        klass.link(:label) { "href" }

        expect(rendered[:_links][:label]).to eq(href: "href")
      end

      it "renders a simple link with a truthy if condition" do
        klass.link(:label, if: true) do
          "href"
        end

        expect(rendered[:_links][:label]).to eq(href: "href")
      end

      it "renders a simple link with an if conditional that evaluations to true" do
        klass.link(:label, if: proc { true }) do
          "href"
        end

        expect(rendered[:_links][:label]).to eq(href: "href")
      end

      it "renders a simple link with a falsy unless condition" do
        klass.link(:label, unless: false) { "href" }

        expect(rendered[:_links][:label]).to eq(href: "href")
      end

      it "does not include link if conditional checks fail" do
        klass.send(:define_method, :return_false) { false }
        klass.send(:define_method, :return_nil) { nil }

        klass.link(:label) { "href" }

        klass.link(:label_2, if: false) { "href" }
        klass.link(:label_3, if: proc { false }) { "href" }
        klass.link(:label_4, if: proc {}) { "href" }
        klass.link(:label_5, if: :return_false) { "href" }

        expect(rendered[:_links].keys).to eq([:label])
      end

      it "includes link if conditional checks pass" do
        klass.send(:define_method, :return_true) { true }
        klass.send(:define_method, :return_one) { 1 }

        klass.link(:label) { "href" }

        klass.link(:label_2, if: true) { "href" }
        klass.link(:label_3, if: proc { true }) { "href" }
        klass.link(:label_4, if: proc { 1 }) { "href" }
        klass.link(:label_5, if: :return_true) { "href" }

        expected = %i[label label_2 label_3 label_4 label_5]
        expect(rendered[:_links].keys).to eq(expected)
      end
    end

    describe "options[:include_links]" do
      let :klass do
        Class.new do
          include Halitosis::Base
          include Halitosis::Links
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
          include Halitosis::Base
          include Halitosis::Links

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
