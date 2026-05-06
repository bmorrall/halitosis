# Halitosis

> bmorrall: I’ve come up with the best name for a rails library!!!
>
> bmorrall: HAL is an API design standard. I like what it does, but it doesn’t fully mesh well with rails.
>
> bmorrall: So I’m thinking of adapting the standard to work better with rails, and bundling up a library to help generate the required data from it
>
> bmorrall: Calling it "rails_is_hal"
>
> daveabbott: Or Halitosis.
>
> bmorrall: That’s also not a bad idea, and slightly more professional sounding

Provides an interface for serializing resources as JSON with HAL-like links and relationships, with additonal meta and permissions info.

Need something more standardized ([JSON:API](https://jsonapi.org/), or [HAL](https://datatracker.ietf.org/doc/html/draft-kelly-json-hal-11))? Most of this code was converted from [halogen](https://github.com/mode/halogen); which is a great alternative for HAL+JSON serialization.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "halitosis"
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install halitosis
```

## Usage

### Quick start

Create a serializer class, include `Halitosis`, declare a resource, and define fields:

```ruby
class ArticleSerializer
  include Halitosis

  resource :article

  identifier :id

  attribute :title
  attribute :body

  link(:self) { "/articles/#{article.id}" }
end
```

Instantiate with the resource as the first argument, then call `render` or `to_json`:

```ruby
serializer = ArticleSerializer.new(article)

serializer.render
# => {
#      article: {
#        id: 1,
#        title: "Hello World",
#        body: "...",
#        _links: { self: { href: "/articles/1" } }
#      }
#    }

serializer.to_json
# => '{"article":{"id":1,"title":"Hello World",...}}'
```

### Serializer types

#### 1. Simple

Not associated with any particular resource or collection — useful for API entry points or custom response shapes:

```ruby
class ApiRootSerializer
  include Halitosis

  link(:self) { "/api" }
  link(:articles) { "/api/articles" }
end

ApiRootSerializer.new.render
# => { _links: { self: { href: "/api" }, articles: { href: "/api/articles" } } }
```

#### 2. Resource

Wraps a single object. Declare it with `resource`, and `#initialize` will accept the resource as its first argument:

```ruby
class ArticleSerializer
  include Halitosis

  resource :article   # exposes the resource as `article` inside the serializer

  identifier :id      # calls article.id
  attribute :title    # calls article.title
end

ArticleSerializer.new(article).render
# => { article: { id: 1, title: "Hello World" } }
```

#### 3. Collection

Wraps a collection of items. Declare it with `collection`, providing a block that maps each item to a Halitosis serializer instance:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do
    collection.map { |article| ArticleSerializer.new(article) }
  end
end

ArticlesSerializer.new(Article.all).render
# => { articles: [ { id: 1, title: "Hello World" }, ... ] }
```

### Identifiers

Identifiers are rendered before other attributes and are typically used for primary keys:

```ruby
identifier :id              # calls article.id on the resource
identifier :uuid do
  SecureRandom.uuid
end
```

Only one identifier may be defined per serializer.

### Attributes

Attributes can be defined in several ways:

```ruby
# Delegate to the resource method of the same name
attribute :title

# Inline block
attribute(:summary) { article.body.truncate(100) }

# Static value
attribute :version, value: 1

# Private helper method
attribute(:word_count) { count_words }

def count_words
  article.body.split.size
end
```

Attributes also support the legacy `property` alias:

```ruby
property :title
property(:summary) { article.body.truncate(100) }
```

#### Conditionals

Use `if` or `unless` to conditionally include any field:

```ruby
# With a method name
attribute :draft_notes, if: :show_draft_notes?

def show_draft_notes?
  article.draft?
end

# With a proc
attribute :published_at, unless: proc { article.published_at.nil? }

# Works on links and relationships too
link :edit, if: :can_edit?
relationship :comments, unless: proc { article.comments.empty? } do
  article.comments.map { |c| CommentSerializer.new(c) }
end
```

### Links

Simple link:

```ruby
link(:self) { "/articles/#{article.id}" }
# => { _links: { self: { href: "/articles/1" } } }
```

Templated link (follows the [HAL](https://datatracker.ietf.org/doc/html/draft-kelly-json-hal-11) `templated` convention):

```ruby
link(:find, :templated) { "/articles/{?id}" }
# => { _links: { find: { href: "/articles/{?id}", templated: true } } }
```

Suppress all links at render time with `include_links: false`:

```ruby
ArticleSerializer.new(article, include_links: false).render
# => { article: { id: 1, title: "Hello World" } }
```

### Relationships

Relationships allow embedding associated serializers inside `_relationships`. They are **opt-in**: they are only rendered when explicitly requested.

One-to-one:

```ruby
relationship(:author) { UserSerializer.new(article.author) }
# => { article: { ..., _relationships: { author: { id: 5, name: "Alice" } } } }
```

One-to-many (array of serializers):

```ruby
relationship(:comments) do
  article.comments.map { |comment| CommentSerializer.new(comment) }
end
# => { article: { ..., _relationships: { comments: [ ... ] } } }
```

One-to-many (collection serializer):

```ruby
relationship(:comments) { CommentsSerializer.new(article.comments) }
```

The `rel` method is a shorthand alias for `relationship`:

```ruby
rel(:author) { UserSerializer.new(article.author) }
rel(:comments) { article.comments.map { |c| CommentSerializer.new(c) } }
```

#### Including relationships

Pass `include:` when instantiating to request relationships. Excluded relationships are not evaluated:

```ruby
# Hash syntax
ArticleSerializer.new(article, include: { author: true, comments: true })

# Array syntax
ArticleSerializer.new(article, include: ["author", "comments"])

# Comma-joined string
ArticleSerializer.new(article, include: "author,comments")
```

Relationships can be nested to any depth:

```ruby
# Hash syntax
ArticleSerializer.new(article, include: {
  author: {
    avatar: true
  },
  comments: {
    author: true
  }
})

# Dot-notation string
ArticleSerializer.new(article, include: "author.avatar,comments.author")
```

Include relationships on collections the same way:

```ruby
ArticlesSerializer.new(Article.all, include: "articles.author")
```

### Meta

Use `meta` to include read-only metadata alongside a resource (timestamps, counts, etc.):

```ruby
class ArticleSerializer
  include Halitosis

  resource :article

  identifier :id
  attribute :title

  meta(:created_at) { article.created_at.iso8601 }
  meta(:updated_at) { article.updated_at.iso8601 }
end

ArticleSerializer.new(article).render
# => {
#      article: {
#        id: 1,
#        title: "Hello World",
#        _meta: {
#          created_at: "2024-09-30T20:46:00Z",
#          updated_at: "2024-10-01T08:00:00Z"
#        }
#      }
#    }
```

Suppress meta at render time with `include_meta: false`:

```ruby
ArticleSerializer.new(article, include_meta: false).render
```

### Permissions

Use `permission` to communicate access rights to clients:

```ruby
class ArticleSerializer
  include Halitosis

  resource :article

  identifier :id
  attribute :title

  permission(:edit) { policy.edit? }
  permission(:destroy) { policy.destroy? }
end

ArticleSerializer.new(article).render
# => {
#      article: {
#        id: 1,
#        title: "Hello World",
#        _permissions: { edit: true, destroy: false }
#      }
#    }
```

Suppress permissions at render time with `include_permissions: false`:

```ruby
ArticleSerializer.new(article, include_permissions: false).render
```

### Root-level fields

`root_link`, `root_meta`, and `root_permission` render outside the resource envelope. This is useful for pagination metadata or top-level navigation links on collection responses:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do
    collection.map { |article| ArticleSerializer.new(article) }
  end

  root_link(:self) { "/articles" }
  root_link(:next, :templated) { "/articles?page={?page}" }

  root_meta(:total) { collection.total_count }
  root_meta(:per_page, value: 25)

  root_permission(:create) { policy.create? }
end

ArticlesSerializer.new(articles).render
# => {
#      articles: [ ... ],
#      _links: {
#        self: { href: "/articles" },
#        next: { href: "/articles?page={?page}", templated: true }
#      },
#      _meta: { total: 42, per_page: 25 },
#      _permissions: { create: true }
#    }
```

### Render options summary

| Option | Default | Description |
| --- | --- | --- |
| `include:` | `{}` | Relationships to include (hash, array, or string) |
| `include_root:` | resource name | Override root key, or `false` to omit the wrapper |
| `include_links:` | `true` | Set to `false` to omit all `_links` |
| `include_meta:` | `true` | Set to `false` to omit all `_meta` |
| `include_permissions:` | `true` | Set to `false` to omit all `_permissions` |

```ruby
# Omit the root wrapper entirely
ArticleSerializer.new(article, include_root: false).render
# => { id: 1, title: "Hello World", ... }

# Use a custom root key
ArticleSerializer.new(article, include_root: "post").render
# => { post: { id: 1, title: "Hello World", ... } }
```

### Using with Rails

When Halitosis is loaded in a Rails application, URL helpers are automatically available inside serializer blocks:

```ruby
class ArticleSerializer
  include Halitosis

  resource :article

  identifier :id
  attribute :title

  link(:self)   { article_url(article) }
  link(:edit)   { edit_article_url(article) }
  link(:index)  { articles_url }
end
```

Render directly from a controller action using the `renderable:` option:

```ruby
# As a renderable (automatically reads `include` from request params)
render renderable: ArticleSerializer.new(article)

# Or pass as :json to control rendering explicitly
render json: ArticleSerializer.new(article)
```

When using `renderable:`, Halitosis will automatically forward the `include` query parameter from the request to the serializer, so clients can request relationships via `?include=author,comments` without any extra controller code.

### ErrorsSerializer

`Halitosis::ErrorsSerializer` serializes an `ActiveModel::Errors` collection into a JSON-compatible errors array. It is available when Halitosis is loaded inside a Rails application.

The output follows a JSON:API-inspired structure with `id`, `detail`, and `source.pointer` fields:

```ruby
render renderable: Halitosis::ErrorsSerializer.new(record.errors), status: :unprocessable_entity

# Or as :json if you need to control rendering explicitly
render json: Halitosis::ErrorsSerializer.new(record.errors), status: :unprocessable_entity
```

```json
{
  "errors": [
    {
      "id": "title_blank",
      "detail": "Title can't be blank",
      "source": { "pointer": "/title" }
    },
    {
      "id": "body_too_short",
      "detail": "Body is too short (minimum is 10 characters)",
      "source": { "pointer": "/body" }
    }
  ]
}
```

Pass `param:` to scope the source pointer under a named namespace — useful when the client submits nested params:

```ruby
Halitosis::ErrorsSerializer.new(record.errors, param: "article").as_json
# source pointers become "/article/title", "/article/body", etc.
```

Field behaviour:

| Field | Value |
| --- | --- |
| `id` | `"attribute_type"` (e.g. `"title_blank"`), or just `"type"` for base errors. Omitted when the error type is not a Symbol (e.g. a custom message string). |
| `detail` | `error.full_message` |
| `source.pointer` | JSON Pointer to the attribute (e.g. `"/title"`). Omitted for base errors and errors with no attribute. |


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bmorrall/halitosis. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/bmorrall/halitosis/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Halitosis project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/bmorrall/halitosis/blob/main/CODE_OF_CONDUCT.md).
