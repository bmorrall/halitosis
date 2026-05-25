# frozen_string_literal: true

module Halitosis
  # Wraps a paginated collection with optional cursor metadata, for use with
  # +paginate_by_cursor+.
  #
  # Return a +CursorResult+ from your +paginate_by_cursor+ block to expose
  # +next_cursor+ and/or +prev_cursor+ to +cursor_links+ and +cursor_meta+.
  #
  # @example
  #   paginate_by_cursor default_size: 25 do |collection, after, _before, size|
  #     records = collection.where("id > ?", after || 0).limit(size + 1)
  #     has_more = records.size > size
  #     records = records.first(size)
  #
  #     Halitosis::CursorResult.new(
  #       records,
  #       next_cursor: has_more ? records.last.id.to_s : nil
  #     )
  #   end
  #
  class CursorResult
    attr_reader :collection, :next_cursor, :prev_cursor

    # @param collection [Object] the paginated collection
    # @param next_cursor [String, nil] opaque cursor pointing forward in the result set
    # @param prev_cursor [String, nil] opaque cursor pointing backward in the result set
    def initialize(collection, next_cursor: nil, prev_cursor: nil)
      @collection = collection
      @next_cursor = next_cursor
      @prev_cursor = prev_cursor
    end
  end
end
