# frozen_string_literal: true

RSpec.describe Halitosis::ErrorsSerializer, :rails do
  # Lightweight stand-in for ActiveModel::Error
  error_struct = Struct.new(:attribute, :type, :full_message)

  describe "#as_json" do
    let(:blank_title) { error_struct.new(:title, :blank, "Title can't be blank") }
    let(:invalid_body) { error_struct.new(:body, :invalid, "Body is invalid") }
    let(:base_error) { error_struct.new(:base, :forbidden, "You are not allowed to do that") }
    let(:custom_message) { error_struct.new(:title, "is way too long", "Title is way too long") }
    let(:no_attribute) { error_struct.new(nil, :blank, "can't be blank") }

    context "with a single attribute error" do
      subject(:result) { described_class.new([blank_title]).as_json }

      it "returns an errors array" do
        expect(result["errors"].size).to eq 1
      end

      it "sets id from attribute and type" do
        expect(result["errors"].first["id"]).to eq "title_blank"
      end

      it "sets detail from full_message" do
        expect(result["errors"].first["detail"]).to eq "Title can't be blank"
      end

      it "sets source pointer to the attribute path" do
        expect(result["errors"].first["source"]["pointer"]).to eq "/title"
      end
    end

    context "with param: option" do
      subject(:result) { described_class.new([blank_title], param: "article").as_json }

      it "scopes the source pointer under the param" do
        expect(result["errors"].first["source"]["pointer"]).to eq "/article/title"
      end
    end

    context "with a base error" do
      subject(:result) { described_class.new([base_error]).as_json }

      it "uses only the error type as id" do
        expect(result["errors"].first["id"]).to eq "forbidden"
      end

      it "omits source from the output" do
        expect(result["errors"].first).not_to have_key("source")
      end
    end

    context "with a non-Symbol type (custom message)" do
      subject(:result) { described_class.new([custom_message]).as_json }

      it "omits id from the output" do
        expect(result["errors"].first).not_to have_key("id")
      end

      it "still includes detail" do
        expect(result["errors"].first["detail"]).to eq "Title is way too long"
      end
    end

    context "with an error with no attribute" do
      subject(:result) { described_class.new([no_attribute]).as_json }

      it "omits source from the output" do
        expect(result["errors"].first).not_to have_key("source")
      end
    end

    context "with multiple errors" do
      subject(:result) { described_class.new([blank_title, invalid_body, base_error]).as_json }

      it "includes all errors" do
        expect(result["errors"].size).to eq 3
      end

      it "renders each error correctly" do
        expect(result["errors"]).to contain_exactly(
          {"id" => "title_blank", "detail" => "Title can't be blank", "source" => {"pointer" => "/title"}},
          {"id" => "body_invalid", "detail" => "Body is invalid", "source" => {"pointer" => "/body"}},
          {"id" => "forbidden", "detail" => "You are not allowed to do that"}
        )
      end
    end

    context "with an empty errors collection" do
      subject(:result) { described_class.new([]).as_json }

      it "returns an empty errors array" do
        expect(result).to eq("errors" => [])
      end
    end
  end

  describe "with ActiveModel::Errors" do
    before do
      stub_const("TestArticle", Class.new do
        include ActiveModel::Model

        attr_accessor :title, :body

        validates :title, presence: true
        validates :body, length: {minimum: 10}
      end)

      record.valid?
    end

    let(:record) { TestArticle.new(title: nil, body: "short") }

    it "serializes ActiveModel::Errors" do
      result = described_class.new(record.errors).as_json

      expect(result["errors"]).to include(
        hash_including("id" => "title_blank", "source" => {"pointer" => "/title"})
      )
    end

    it "scopes pointers under param: when provided" do
      result = described_class.new(record.errors, param: "article").as_json

      expect(result["errors"].map { |e| e.dig("source", "pointer") }).to all(start_with("/article/"))
    end
  end

  describe "Rails renderable protocol" do
    subject(:serializer) { described_class.new([blank_title]) }

    let(:blank_title) { error_struct.new(:title, :blank, "Title can't be blank") }

    describe "#format" do
      it "returns :json" do
        expect(serializer.format).to eq :json
      end
    end

    describe "#render_in" do
      it "renders plain JSON via the view context" do
        view_context = instance_double(ActionView::Base)
        expect(view_context).to receive(:render).with(plain: serializer.as_json.to_json)

        serializer.render_in(view_context)
      end
    end
  end
end
