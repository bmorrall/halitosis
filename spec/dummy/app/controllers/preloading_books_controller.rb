class PreloadingBooksController < ApplicationController
  def show
    id = params[:id].to_i
    book = Example.new(id: id, name: "Book #{id}")

    render renderable: PreloadingBookSerializer.new(book)
  end
end
