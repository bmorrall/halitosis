# frozen_string_literal: true

RSpec.describe "Precheck" do
  # ─── helpers ────────────────────────────────────────────────────────────────

  def build_resource_serializer(&block)
    Class.new do
      include Halitosis

      resource :article
      attribute(:title) { resource[:title] }
      instance_eval(&block) if block
    end
  end

  def build_collection_serializer(item_ser, &block)
    Class.new do
      include Halitosis

      collection :articles do |articles|
        articles.map { |a| item_ser.new(a) }
      end
      instance_eval(&block) if block
    end
  end

  # ─── raise_invalid_filter_parameter ─────────────────────────────────────────

  describe "raise_invalid_filter_parameter" do
    let(:item_klass) do
      Class.new do
        include Halitosis

        resource :article
        attribute(:title) { resource[:title] }
      end
    end

    let(:articles) { [{title: "Hello"}] }

    let(:klass) do
      item_ser = item_klass
      Class.new do
        include Halitosis

        collection :articles do |articles|
          articles.map { |a| item_ser.new(a) }
        end

        filterable_by :published_at do |collection, _value|
          collection
        end

        precheck :validate_published_at do |params|
          raise_invalid_filter_parameter("published_at") if params[:filter]&.key?(:published_at)
        end
      end
    end

    context "when the precheck passes" do
      it "renders normally" do
        result = klass.new(articles).render
        expect(result[:articles].first[:title]).to eq("Hello")
      end
    end

    context "when the precheck fails" do
      it "raises InvalidFilterParameter naming the field" do
        exception = nil

        begin
          klass.new(articles, filter: {published_at: "2024-01-01"}).render
        rescue Halitosis::InvalidFilterParameter => e
          exception = e
        end

        expect(exception).to be_an_instance_of(Halitosis::InvalidFilterParameter)
        expect(exception.parameter).to eq("filter[published_at]")
        expect(exception.message).to match(/can not be filtered by 'published_at'/i)
      end
    end
  end

  # ─── raise_invalid_sort_parameter ───────────────────────────────────────────

  describe "raise_invalid_sort_parameter" do
    let(:item_klass) do
      Class.new do
        include Halitosis

        resource :article
        attribute(:title) { resource[:title] }
      end
    end

    let(:klass) do
      item_ser = item_klass
      Class.new do
        include Halitosis

        collection :articles do |articles|
          articles.map { |a| item_ser.new(a) }
        end

        precheck :validate_sort do |params|
          if (sort_param = params[:sort])
            allowed = %w[title]
            raise_invalid_sort_parameter(sort_param) unless allowed.include?(sort_param.delete_prefix("-"))
          end
        end
      end
    end

    let(:articles) { [{title: "Alpha"}, {title: "Beta"}] }

    context "when sorting by an allowed field" do
      it "renders normally" do
        result = klass.new(articles).render
        expect(result[:articles].map { |a| a[:title] }).to eq(%w[Alpha Beta])
      end
    end

    context "when sorting by a disallowed field" do
      it "raises InvalidSortParameter naming the sort token" do
        exception = nil

        begin
          klass.new(articles, sort: "secret_field").render
        rescue Halitosis::InvalidSortParameter => e
          exception = e
        end

        expect(exception).to be_an_instance_of(Halitosis::InvalidSortParameter)
        expect(exception.parameter).to eq("sort")
        expect(exception.message).to match(/can not be sorted by 'secret_field'/i)
      end
    end
  end

  # ─── raise_invalid_pagination_parameter ─────────────────────────────────────

  describe "raise_invalid_pagination_parameter" do
    let(:item_klass) do
      Class.new do
        include Halitosis

        resource :article
        attribute(:title) { resource[:title] }
      end
    end

    let(:max_page_size) { 50 }

    let(:klass) do
      item_ser = item_klass
      max = max_page_size
      Class.new do
        include Halitosis

        collection :articles do |articles|
          articles.map { |a| item_ser.new(a) }
        end

        paginate_by_page ->(c) { nil }, default_page_size: 25 do |collection, number, size| # rubocop:disable Style/NilLambda
          collection[((number - 1) * size), size] || []
        end

        precheck :validate_page_size do |params|
          page = params[:page]
          if page && page[:size]
            size = page[:size].to_i
            raise_invalid_pagination_parameter("size", "must be less than #{max}") if size >= max
          end
        end
      end
    end

    let(:articles) { [{title: "Alpha"}, {title: "Beta"}] }

    context "when page size is within the allowed maximum" do
      it "renders normally" do
        result = klass.new(articles, page: {size: 10}).render
        expect(result[:articles].length).to eq(2)
      end
    end

    context "when page size meets or exceeds the maximum (50)" do
      it "raises InvalidPaginationParameter naming the param and the constraint" do
        exception = nil

        begin
          klass.new(articles, page: {size: 500}).render
        rescue Halitosis::InvalidPaginationParameter => e
          exception = e
        end

        expect(exception).to be_an_instance_of(Halitosis::InvalidPaginationParameter)
        expect(exception.parameter).to eq("page[size]")
        expect(exception.message).to match(/can not be paginated with the provided 'page\[size\]' value/i)
        expect(exception.message).to match(/must be less than 50/i)
      end
    end
  end

  # ─── raise_invalid_include_parameter ────────────────────────────────────────

  describe "raise_invalid_include_parameter" do
    let(:klass) do
      build_resource_serializer do
        precheck :validate_includes do |params|
          requested = Array(params[:include])
          allowed = [:comments]
          disallowed = requested.map(&:to_sym) - allowed
          raise_invalid_include_parameter(disallowed.first.to_s) if disallowed.any?
        end
      end
    end

    context "when including an allowed relationship" do
      it "does not raise during the precheck" do
        result = klass.new({title: "Hello"}).render
        expect(result.dig(:article, :title)).to eq("Hello")
      end
    end

    context "when including an unknown relationship" do
      it "raises InvalidIncludeParameter naming the relationship path" do
        exception = nil

        begin
          klass.new({title: "Hello"}, include: :author).render
        rescue Halitosis::InvalidIncludeParameter => e
          exception = e
        end

        expect(exception).to be_an_instance_of(Halitosis::InvalidIncludeParameter)
        expect(exception.parameter).to eq("include")
        expect(exception.message).to match(/does not have a `author` relationship path/i)
      end
    end
  end

  # ─── multiple prechecks ──────────────────────────────────────────────────────

  describe "multiple prechecks" do
    let(:klass) do
      build_resource_serializer do
        precheck :validate_filter do |params|
          raise_invalid_filter_parameter("status") if options[:trigger_filter]
        end

        precheck :validate_sort do |params|
          raise_invalid_sort_parameter("name") if options[:trigger_sort]
        end
      end
    end

    it "runs both prechecks and raises on the first failing one" do
      expect { klass.new({}, trigger_filter: true).render }
        .to raise_error(Halitosis::InvalidFilterParameter)
    end

    it "runs the second precheck independently" do
      expect { klass.new({}, trigger_sort: true).render }
        .to raise_error(Halitosis::InvalidSortParameter)
    end

    it "renders normally when all prechecks pass" do
      result = klass.new({title: "OK"}).render
      expect(result).to be_a(Hash)
    end

    context "when the same name is reused" do
      it "replaces the original precheck with the new one" do
        klass_with_replacement = build_resource_serializer do
          precheck :validate_filter do |params|
            raise_invalid_filter_parameter("original") if options[:trigger_original]
          end

          # Redefines :validate_filter — the original must not run
          precheck :validate_filter do |params|
            raise_invalid_sort_parameter("replacement") if options[:trigger_replacement]
          end
        end

        expect { klass_with_replacement.new({}, trigger_original: true).render }
          .not_to raise_error

        expect { klass_with_replacement.new({}, trigger_replacement: true).render }
          .to raise_error(Halitosis::InvalidSortParameter)
      end
    end
  end

  # ─── inheritance ─────────────────────────────────────────────────────────────

  describe "inheritance" do
    let(:parent_klass) do
      build_resource_serializer do
        precheck :validate_archived do |params|
          raise_invalid_filter_parameter("archived") if options[:archived]
        end
      end
    end

    let(:child_klass) do
      p = parent_klass
      Class.new(p) do
        precheck :validate_child do |params|
          raise_invalid_sort_parameter("secret") if options[:trigger_child]
        end
      end
    end

    it "inherits prechecks from the parent" do
      expect { child_klass.new({}, archived: true).render }
        .to raise_error(Halitosis::InvalidFilterParameter)
    end

    it "also runs the child's own prechecks" do
      expect { child_klass.new({}, trigger_child: true).render }
        .to raise_error(Halitosis::InvalidSortParameter)
    end

    it "does not propagate child prechecks back to the parent" do
      expect { parent_klass.new({}, trigger_child: true).render }
        .not_to raise_error
    end
  end
end
