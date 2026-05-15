class ArticleSerializer
  include Halitosis

  resource :article

  attribute :name
  attribute :score
end
