# Parent serializer whose :author relationship renders a PreloadingAuthorSerializer
# inline as a nested child. Used to exercise the Base#render_child path, where
# before_render must be called on the child before render_with_context.
class PreloadingBookSerializer
  include Halitosis

  resource :book

  attribute :name

  relationship :author do
    PreloadingAuthorSerializer.new(
      Example.new(id: book.id * 10 + 1, name: "Author of #{book.name}")
    )
  end
end
