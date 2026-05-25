# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::CursorField do
  let(:items) { (1..20).map { |i| {id: i} } }

  let :klass do
    Class.new do
      include Halitosis

      collection :items do |collection|
        collection
      end

      paginate_by_cursor default_size: 5 do |collection, after, _before, size|
        start_id = after&.to_i || 0
        records = collection.select { |i| i[:id] > start_id }.first(size + 1)
        has_more = records.size > size
        records = records.first(size)

        Halitosis::CursorResult.new(
          records,
          next_cursor: has_more ? records.last[:id].to_s : nil,
          prev_cursor: after ? records.first[:id].to_s : nil
        )
      end
    end
  end

  let(:field) { klass.fields.singleton(described_class) }
  let(:context) { klass.new(items).send(:build_context, {}) }

  describe "#apply_pagination" do
    context "without cursor params" do
      it "paginates the collection using default_size" do
        field.apply_pagination(context)

        expect(context.collection.map { |i| i[:id] }).to eq((1..5).to_a)
      end

      it "stores the CursorResult on the context" do
        field.apply_pagination(context)

        expect(field.fetch_result(context)).to be_a(Halitosis::CursorResult)
      end
    end

    context "with page[:after]" do
      let(:context) { klass.new(items, page: {after: "5"}).send(:build_context, {}) }

      it "pages from the given cursor" do
        field.apply_pagination(context)

        expect(context.collection.map { |i| i[:id] }).to eq((6..10).to_a)
      end
    end

    context "when the block returns a plain collection (no CursorResult)" do
      let :plain_klass do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_cursor default_size: 5 do |collection, _after, _before, size|
            collection.first(size)
          end
        end
      end

      it "sets the collection without storing a CursorResult" do
        ctx = plain_klass.new(items).send(:build_context, {})
        plain_field = plain_klass.fields.singleton(described_class)
        plain_field.apply_pagination(ctx)

        expect(ctx.collection.size).to eq(5)
        expect(plain_field.fetch_result(ctx)).to be_nil
      end
    end

    context "when the block returns nil" do
      let :nil_klass do
        Class.new do
          include Halitosis

          collection :items do |collection|
            collection
          end

          paginate_by_cursor default_size: 5 do |_collection, _after, _before, _size|
            nil
          end
        end
      end

      it "returns nil" do
        ctx = nil_klass.new(items).send(:build_context, {})
        nil_field = nil_klass.fields.singleton(described_class)

        expect(nil_field.apply_pagination(ctx)).to be_nil
      end
    end
  end

  describe "#next_cursor" do
    it "returns nil when no cursor result is stored" do
      expect(field.next_cursor(context)).to be_nil
    end

    it "returns the next cursor after pagination" do
      field.apply_pagination(context)

      expect(field.next_cursor(context)).to eq("5")
    end

    it "returns nil when on the last page" do
      ctx = klass.new(items, page: {after: "16"}).send(:build_context, {})
      field.apply_pagination(ctx)

      expect(field.next_cursor(ctx)).to be_nil
    end
  end

  describe "#prev_cursor" do
    it "returns nil when no cursor result is stored" do
      expect(field.prev_cursor(context)).to be_nil
    end

    it "returns the prev cursor when an after param was given" do
      ctx = klass.new(items, page: {after: "5"}).send(:build_context, {})
      field.apply_pagination(ctx)

      expect(field.prev_cursor(ctx)).to eq("6")
    end

    it "returns nil when no after param was given (first page)" do
      field.apply_pagination(context)

      expect(field.prev_cursor(context)).to be_nil
    end
  end

  describe "#validate" do
    it "raises InvalidField when no procedure is set" do
      bad_field = described_class.new(:cursor_pagination, {}, nil)

      expect { bad_field.validate }
        .to raise_error(Halitosis::InvalidField, /must be defined with a proc/i)
    end

    it "returns true when a procedure is set" do
      good_field = described_class.new(:cursor_pagination, {}, -> {})

      expect(good_field.validate).to be true
    end
  end
end
