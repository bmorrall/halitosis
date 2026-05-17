# frozen_string_literal: true

RSpec.describe Halitosis::CollectionPaginatable::PagyHelper do
  describe ".pagy" do
    context "with a stubbed Pagy::Offset" do
      let(:pagy_obj) { double(page: 1, pages: 2, previous: nil, next: nil, limit: 10, offset: 0) }
      let(:records) { (1..10).to_a }
      let(:coll) do
        dbl = double
        allow(dbl).to receive_messages(count: 20, offset: dbl, limit: records)
        dbl
      end

      before do
        stub_const("Pagy::Offset", Class.new)
        allow(Pagy::Offset).to receive(:new).and_return(pagy_obj)
        allow(pagy_obj).to receive_messages(offset: 0, limit: 10)
      end

      it "calls Pagy::Offset.new with count, page, and limit from page_params" do
        result = described_class.pagy(coll, {number: 1, size: 10})
        expect(Pagy::Offset).to have_received(:new).with(count: 20, page: 1, limit: 10)
        expect(result).to eq([pagy_obj, records])
      end

      it "omits limit when page_params[:size] is absent, letting Pagy use its own default" do
        described_class.pagy(coll, {number: 1})
        expect(Pagy::Offset).to have_received(:new).with(count: 20, page: 1)
      end

      it "allows overriding page number and limit via extra kwargs" do
        allow(pagy_obj).to receive(:limit).and_return(5)
        described_class.pagy(coll, {}, page: 3, limit: 5)
        expect(Pagy::Offset).to have_received(:new).with(count: 20, page: 3, limit: 5)
      end
    end
  end
end
