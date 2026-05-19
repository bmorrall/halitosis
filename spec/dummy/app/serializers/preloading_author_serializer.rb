# Child serializer with a relationship that uses `preload:` to fetch its tags.
#
# The relationship block deliberately has NO nil-fallback (`tags.map` not
# `(tags || []).map`). This means that if +before_render+ is never called on
# this serializer, +preload_context+ never fires, the preloaded value is nil,
# and `nil.map` raises NoMethodError — causing any request spec that exercises
# this path to fail with a 500 rather than silently returning an empty array.
#
# This serializer is used by PreloadingBookSerializer (inline relationship, tests
# Base#render_child) and PreloadingLibrarySerializer (hoisted relationship, tests
# CollectIncludes#render_child).
class PreloadingAuthorSerializer
  include Halitosis

  resource :author

  # identifier is required for CollectIncludes to hoist this child into the
  # included registry rather than rendering it inline.
  identifier :id

  attribute :name

  relationship :tags, preload: :fetch_tags do |tags|
    # No nil guard — will raise NoMethodError if before_render was not called.
    tags.map { |t| PreloadingTagSerializer.new(t) }
  end

  # Returns two deterministic tag objects keyed on the author's own id, so
  # tests can assert exact names without any external state.
  def fetch_tags
    [
      Example.new(id: author.id * 10 + 1, name: "tag-#{author.id}-a"),
      Example.new(id: author.id * 10 + 2, name: "tag-#{author.id}-b")
    ]
  end
end
