# frozen_string_literal: true

module Halitosis
  module CollectionPaginatable
    # Utility module providing a single module function for building a
    # +Pagy::Offset+ instance from a collection and page params.
    #
    # Used internally by the +paginate_with_pagy+ pagination field; not mixed
    # into serializer classes.
    #
    module PagyHelper
      module_function

      # Paginate +collection+ using +Pagy::Offset+ and return +[pagy, records]+.
      #
      # @param collection [#count, #offset, #limit] the collection to paginate
      # @param page_params [Hash] page parameters from the render context
      # @param opts [Hash] extra kwargs forwarded to +Pagy::Offset.new+
      #   (e.g. +count:+, +limit:+, +page:+)
      # @return [Array(Pagy::Offset, Object)] +[pagy, records]+
      #
      def pagy(collection, page_params = {}, **opts)
        page_num = Integer(opts.delete(:page) || page_params[:number] || 1)
        page_size = opts.delete(:limit) || page_params[:size]
        kwargs = {count: collection.count, page: page_num}
        kwargs[:limit] = Integer(page_size) unless page_size.nil?

        pagy_obj = Pagy::Offset.new(**kwargs.merge(opts))
        [pagy_obj, collection.offset(pagy_obj.offset).limit(pagy_obj.limit)]
      end
    end
  end
end
