# frozen_string_literal: true

RSpec.describe Halitosis::Attributes do
  let :klass do
    Class.new {
      include Halitosis::Base
      include Halitosis::Attributes
    }
  end

  describe Halitosis::Attributes::ClassMethods do
    describe "#attribute" do
      it "defines an attribute field" do
        expect do
          klass.attribute(:foo)
        end.to change(klass.fields, :size).by(1)

        inserted_field = klass.fields.for_type(Halitosis::Attributes::Field).last
        expect(inserted_field).to be_a(Halitosis::Attributes::Field)
        expect(inserted_field.name).to eq(:foo)
      end
    end
  end

  describe Halitosis::Attributes::InstanceMethods do
    let :serializer do
      klass.new
    end

    describe "#before_render" do
      it "registers fields in query_params when fields option is present" do
        klass.attribute(:foo, value: "bar")

        context = serializer.send(:build_context, fields: {articles: "body,title"})
        serializer.before_render(context)

        expect(context.query_params[:fields]).to eq(articles: "body,title")
      end

      it "sorts field names in registered query_params for stable URL output" do
        klass.attribute(:foo, value: "bar")

        context = serializer.send(:build_context, fields: {articles: "title,body"})
        serializer.before_render(context)

        expect(context.query_params[:fields]).to eq(articles: "body,title")
      end

      it "omits unsupported-type entries from registered query_params" do
        klass.attribute(:foo, value: "bar")

        context = serializer.send(:build_context, fields: {articles: "foo", people: 42})
        serializer.before_render(context)

        expect(context.query_params[:fields]).to eq(articles: "foo")
      end

      it "includes blank entries in query_params as empty strings" do
        klass.attribute(:foo, value: "bar")

        context = serializer.send(:build_context, fields: {articles: "foo", people: ""})
        serializer.before_render(context)

        expect(context.query_params[:fields]).to eq(articles: "foo", people: "")
      end

      it "does not register fields in query_params when all values are unsupported types" do
        klass.attribute(:foo, value: "bar")

        context = serializer.send(:build_context, fields: {articles: 42})
        serializer.before_render(context)

        expect(context.query_params).not_to have_key(:fields)
      end

      it "sets sparse_fields_registry on the context when fields option is present" do
        klass.resource_type = "articles"
        klass.attribute(:foo, value: "bar")

        context = serializer.send(:build_context, fields: {articles: "foo"})
        serializer.before_render(context)

        expect(context.sparse_fields_registry).to eq("articles" => Set["foo"])
      end

      it "does not register fields in query_params when fields option is absent" do
        klass.attribute(:foo, value: "bar")

        context = serializer.send(:build_context)
        serializer.before_render(context)

        expect(context.query_params).not_to have_key(:fields)
      end
    end

    describe "#render_with_context" do
      it "merges super with rendered attributes" do
        allow(serializer).to receive(:attributes).and_return(foo: "bar")

        expect(serializer.render).to eq(foo: "bar")
      end

      it "sets current_sparse_fields on the context for the serializer's resource_type" do
        klass.resource_type = "articles"
        klass.attribute(:foo, value: "bar")

        context = serializer.send(:build_context)
        context.sparse_fields_registry = {"articles" => Set["foo"]}
        serializer.render_with_context(context)

        expect(context.fetch_local(:current_sparse_fields)).to eq(Set["foo"])
      end
    end

    describe "#to_json" do
      it "renders the JSON representation with inline attributes" do
        klass.attribute(:foo, value: "bar")

        expect(serializer.to_json).to eq('{"foo":"bar"}')
      end
    end

    describe "#attributes" do
      it "builds attributes from fields" do
        klass.attribute(:foo, value: "bar")

        expect(serializer.attributes).to eq(foo: "bar")
      end

      it "delegates to the serializer instance when no value or block is given" do
        klass.attribute(:foo)

        allow(serializer).to receive(:foo).and_return("bar")

        expect(serializer.attributes).to eq(foo: "bar")
      end

      it "delegates to the named method when value is a symbol" do
        klass.attribute(:foo, value: :bar)

        allow(serializer).to receive(:bar).and_return("baz")

        expect(serializer.attributes).to eq(foo: "baz")
      end

      context "when resource_type is set and fields param is present" do
        before do
          klass.resource_type = "articles"
          klass.attribute(:title, value: "Hello")
          klass.attribute(:body, value: "World")
          klass.attribute(:author, value: "Alice")
        end

        it "includes only permitted fields when fields is a comma-separated string" do
          result = serializer.render(fields: {"articles" => "title,body"})

          expect(result).to include(title: "Hello", body: "World")
          expect(result).not_to have_key(:author)
        end

        it "includes only permitted fields when fields uses symbol keys" do
          result = serializer.render(fields: {articles: "title,author"})

          expect(result).to include(title: "Hello", author: "Alice")
          expect(result).not_to have_key(:body)
        end

        it "includes only permitted fields when fields value is an array" do
          result = serializer.render(fields: {"articles" => ["title"]})

          expect(result).to include(title: "Hello")
          expect(result).not_to have_key(:body)
          expect(result).not_to have_key(:author)
        end

        it "includes all fields when no matching resource type is present in fields" do
          result = serializer.render(fields: {"people" => "name"})

          expect(result).to include(title: "Hello", body: "World", author: "Alice")
        end

        it "includes all fields when fields param is absent" do
          result = serializer.render

          expect(result).to include(title: "Hello", body: "World", author: "Alice")
        end
      end

      context "when resource_type is not set" do
        before do
          klass.attribute(:foo, value: "bar")
        end

        it "includes all fields even when fields param is present" do
          result = serializer.render(fields: {"anything" => "foo"})

          expect(result).to include(foo: "bar")
        end
      end
    end
  end
end
