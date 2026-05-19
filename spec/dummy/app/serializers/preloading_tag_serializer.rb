# A minimal leaf serializer used by PreloadingAuthorSerializer to represent a
# tag resource. Intentionally has no preloads so all rendering complexity lives
# in the parent (PreloadingAuthorSerializer).
class PreloadingTagSerializer
  include Halitosis

  resource :tag

  attribute :name
end
