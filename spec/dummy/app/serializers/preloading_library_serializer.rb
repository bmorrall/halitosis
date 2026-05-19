# Parent serializer that opts into CollectIncludes sideloading. Because the
# :author child has an identifier, CollectIncludes#render_child hoists it into
# the shared included registry instead of rendering it inline. This exercises
# the CollectIncludes#render_child path, where before_render must be called on
# the hoisted child before render_with_context.
#
# Two relationships (:author and :guest_author) return the same underlying id so
# that specs can also verify the deduplication path: the second occurrence should
# find the child already in the registry and return a stub without re-rendering
# (and without calling before_render a second time).
class PreloadingLibrarySerializer
  include Halitosis

  collect_includes!

  resource :library

  identifier :id

  attribute :name

  relationship :author do
    PreloadingAuthorSerializer.new(
      Example.new(id: library.id * 10 + 1, name: "Author #{library.id}")
    )
  end

  # Intentionally returns the same id as :author so that CollectIncludes
  # deduplicates the two references and emits only one entry in included.author.
  relationship :guest_author do
    PreloadingAuthorSerializer.new(
      Example.new(id: library.id * 10 + 1, name: "Author #{library.id}")
    )
  end
end
