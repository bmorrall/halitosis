require "spec_helper"

# These specs verify that before_render is called on every child serializer
# that passes through render_child, covering two distinct code paths:
#
#   1. Base#render_child — the standard path for inline relationship children.
#   2. CollectIncludes#render_child — the hoisting path that defers included
#      relationships into a shared registry.
#
# Each scenario uses PreloadingAuthorSerializer, which declares:
#
#   relationship :tags, preload: :fetch_tags do |tags|
#     tags.map { |t| PreloadingTagSerializer.new(t) }
#   end
#
# There is deliberately no nil-guard on `tags`. If before_render is never
# called on the child, preload_context never fires, the preloaded value stays
# nil, and `nil.map` raises NoMethodError — producing a 500 response. Every
# test below that requests `include=...tags` therefore acts as a tripwire:
# it fails immediately if the before_render call is removed from render_child.
#
RSpec.describe "before_render is called on child serializers", :rails, type: :request do
  # ---------------------------------------------------------------------------
  # Path 1 — Base#render_child
  #
  # PreloadingBookSerializer has a plain :author relationship (no identifier on
  # the author, no collect_includes! on the book). The author is rendered inline
  # via Base#render_child, which is responsible for calling before_render.
  # ---------------------------------------------------------------------------
  describe "GET /preloading_books/:id" do
    context "when no include param is given" do
      it "renders the book successfully without touching any relationship" do
        get preloading_book_path(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("book", "name")).to eq("Book 1")
        expect(response.parsed_body["book"]).not_to have_key("_relationships")
      end
    end

    context "when include=author is given" do
      it "renders the author inline without raising" do
        get preloading_book_path(1), params: {include: "author"}

        expect(response).to have_http_status(:ok)
      end

      it "includes the author with the correct name" do
        get preloading_book_path(1), params: {include: "author"}

        author = response.parsed_body.dig("book", "_relationships", "author")

        expect(author).to include("name" => "Author of Book 1")
      end

      it "does not render the author's tags (tags relationship not included)" do
        get preloading_book_path(1), params: {include: "author"}

        author = response.parsed_body.dig("book", "_relationships", "author")

        # preload_context must NOT have been asked to preload :tags because the
        # tags relationship is disabled (not in include_options). The author
        # renders without a _relationships key at all.
        expect(author).not_to have_key("_relationships")
      end
    end

    context "when include=author.tags is given" do
      # This is the primary tripwire test. If Base#render_child does not call
      # before_render on the author, preload_context never fires, fetch_tags is
      # never called, and tags is nil inside the relationship block —
      # raising NoMethodError and returning a 500.
      it "renders successfully (would 500 without before_render)" do
        get preloading_book_path(1), params: {include: "author.tags"}

        expect(response).to have_http_status(:ok)
      end

      it "includes the author under _relationships" do
        get preloading_book_path(1), params: {include: "author.tags"}

        author = response.parsed_body.dig("book", "_relationships", "author")

        expect(author).to be_a(Hash)
        expect(author["name"]).to eq("Author of Book 1")
      end

      it "includes two tags under the author's _relationships" do
        get preloading_book_path(1), params: {include: "author.tags"}

        tags = response.parsed_body.dig("book", "_relationships", "author", "_relationships", "tags")

        expect(tags).to be_an(Array)
        expect(tags.size).to eq(2)
      end

      it "renders tags with names derived from the author's id" do
        get preloading_book_path(1), params: {include: "author.tags"}

        # book 1 → author id 11 → tags "tag-11-a" and "tag-11-b"
        tags = response.parsed_body.dig("book", "_relationships", "author", "_relationships", "tags")

        expect(tags.map { |t| t["name"] }).to contain_exactly("tag-11-a", "tag-11-b")
      end

      it "uses the child's own id to compute tag names (per-instance preload)" do
        # Use a different book id to confirm that fetch_tags is called on each
        # author instance with its own resource, not a shared or stale value.
        get preloading_book_path(5), params: {include: "author.tags"}

        # book 5 → author id 51 → tags "tag-51-a" and "tag-51-b"
        tags = response.parsed_body.dig("book", "_relationships", "author", "_relationships", "tags")

        expect(tags.map { |t| t["name"] }).to contain_exactly("tag-51-a", "tag-51-b")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Path 2 — CollectIncludes#render_child (hoisting path)
  #
  # PreloadingLibrarySerializer opts into collect_includes! and the author has
  # identifier :id. When include=author is requested, CollectIncludes#render_child
  # takes the non-collection branch: it builds a child_context, then must call
  # before_render on the child before calling render_with_context so that
  # preload_context runs.
  # ---------------------------------------------------------------------------
  describe "GET /preloading_libraries/:id" do
    context "when no include param is given" do
      it "renders the library without an included key" do
        get preloading_library_path(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("library", "name")).to eq("Library 1")
        expect(response.parsed_body).not_to have_key("included")
      end

      it "renders without touching any relationship" do
        get preloading_library_path(1)

        expect(response.parsed_body["library"]).not_to have_key("_relationships")
      end
    end

    context "when include=author is given" do
      it "renders successfully" do
        get preloading_library_path(1), params: {include: "author"}

        expect(response).to have_http_status(:ok)
      end

      it "hoists the author into the included registry" do
        get preloading_library_path(1), params: {include: "author"}

        expect(response.parsed_body).to have_key("included")
        expect(response.parsed_body.dig("included", "author")).to be_an(Array)
        expect(response.parsed_body.dig("included", "author").size).to eq(1)
      end

      it "stubs the relationship with only the identifier and _type" do
        get preloading_library_path(1), params: {include: "author"}

        stub = response.parsed_body.dig("library", "_relationships", "author")

        expect(stub.keys).to contain_exactly("id", "_type")
        expect(stub["_type"]).to eq("author")
        expect(stub["id"]).to eq(11)
      end

      it "renders the author's name correctly inside the included registry" do
        get preloading_library_path(1), params: {include: "author"}

        author = response.parsed_body.dig("included", "author", 0)

        expect(author["name"]).to eq("Author 1")
      end

      it "does not render the author's tags when tags is not included" do
        get preloading_library_path(1), params: {include: "author"}

        author = response.parsed_body.dig("included", "author", 0)

        expect(author).not_to have_key("_relationships")
      end
    end

    context "when include=author.tags is given" do
      # Primary tripwire for the CollectIncludes path. Without the
      # `child.before_render(child_context)` call added to
      # CollectIncludes#render_child, the hoisted author's preload_context
      # never runs, tags is nil, and `nil.map` raises NoMethodError → 500.
      it "renders successfully (would 500 without before_render in CollectIncludes)" do
        get preloading_library_path(1), params: {include: "author.tags"}

        expect(response).to have_http_status(:ok)
      end

      it "hoists the author into the included registry" do
        get preloading_library_path(1), params: {include: "author.tags"}

        expect(response.parsed_body.dig("included", "author")).to be_an(Array)
        expect(response.parsed_body.dig("included", "author").size).to eq(1)
      end

      it "renders the author's tags inside the included registry" do
        get preloading_library_path(1), params: {include: "author.tags"}

        author = response.parsed_body.dig("included", "author", 0)
        tags = author.dig("_relationships", "tags")

        expect(tags).to be_an(Array)
        expect(tags.size).to eq(2)
      end

      it "renders tag names derived from the hoisted author's id" do
        get preloading_library_path(1), params: {include: "author.tags"}

        # library 1 → author id 11 → tags "tag-11-a" and "tag-11-b"
        tags = response.parsed_body.dig("included", "author", 0, "_relationships", "tags")

        expect(tags.map { |t| t["name"] }).to contain_exactly("tag-11-a", "tag-11-b")
      end

      it "renders tag names using the instance's own id (per-instance preload)" do
        get preloading_library_path(3), params: {include: "author.tags"}

        # library 3 → author id 31 → tags "tag-31-a" and "tag-31-b"
        tags = response.parsed_body.dig("included", "author", 0, "_relationships", "tags")

        expect(tags.map { |t| t["name"] }).to contain_exactly("tag-31-a", "tag-31-b")
      end
    end

    context "when the same author id appears in two relationships (deduplication)" do
      # PreloadingLibrarySerializer has :author and :guest_author, both returning
      # an author with the same id. CollectIncludes must render the author once
      # (calling before_render once), then return a stub for the duplicate
      # without re-rendering or calling before_render again.
      it "renders successfully" do
        get preloading_library_path(2), params: {include: "author.tags,guest_author.tags"}

        expect(response).to have_http_status(:ok)
      end

      it "emits only one author entry in the included registry (dedup)" do
        get preloading_library_path(2), params: {include: "author.tags,guest_author.tags"}

        included_authors = response.parsed_body.dig("included", "author")

        expect(included_authors).to be_an(Array)
        expect(included_authors.size).to eq(1)
      end

      it "stubs both relationships with the same identifier" do
        get preloading_library_path(2), params: {include: "author.tags,guest_author.tags"}

        rels = response.parsed_body.dig("library", "_relationships")

        expect(rels["author"]).to eq(rels["guest_author"])
        expect(rels["author"]["id"]).to eq(21)
        expect(rels["author"]["_type"]).to eq("author")
      end

      it "the single included author entry has correctly preloaded tags" do
        get preloading_library_path(2), params: {include: "author.tags,guest_author.tags"}

        # library 2 → author id 21 → tags "tag-21-a" and "tag-21-b"
        tags = response.parsed_body.dig("included", "author", 0, "_relationships", "tags")

        expect(tags.map { |t| t["name"] }).to contain_exactly("tag-21-a", "tag-21-b")
      end
    end
  end
end
