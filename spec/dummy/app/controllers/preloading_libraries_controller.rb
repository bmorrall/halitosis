class PreloadingLibrariesController < ApplicationController
  def show
    id = params[:id].to_i
    library = Example.new(id: id, name: "Library #{id}")

    render renderable: PreloadingLibrarySerializer.new(library)
  end
end
