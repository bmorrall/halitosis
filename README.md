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
#        _type: "article",
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
# => { article: { id: 1, title: "Hello World", _type: "article" } }
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
# => { articles: [ { id: 1, title: "Hello World", _type: "article" }, ... ] }
```

### Sorting collections

Declare sort fields on a collection serializer with `sortable_by`. The block receives a single Boolean — `true` for ascending, `false` for descending — and must return the sorted collection:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do
    collection.map { |article| ArticleSerializer.new(article) }
  end

  sortable_by :title do |ascending|
    collection.order(title: ascending ? :asc : :desc)
  end

  sortable_by :published_at do |ascending|
    collection.order(published_at: ascending ? :asc : :desc)
  end
end
```

Pass the `sort:` option at render time. Prefix a field name with `-` for descending order:

```ruby
# Single field, ascending
ArticlesSerializer.new(Article.all, sort: "title").render

# Single field, descending
ArticlesSerializer.new(Article.all, sort: "-title").render

# Multiple fields — applied left to right
ArticlesSerializer.new(Article.all, sort: "title,-published_at").render

# Array input is also accepted
ArticlesSerializer.new(Article.all, sort: ["title", "-published_at"]).render
```

Requesting a field that has not been declared with `sortable_by` raises `Halitosis::InvalidQueryParameter`, which Rails maps to a `400 Bad Request` response.

#### Restricting sort directions

Return `nil` from a `sortable_by` block to signal that a particular direction is not supported. Halitosis will raise `InvalidQueryParameter` with the direction-prefixed token, so the client gets a clear error:

```ruby
sortable_by :name do |ascending|
  # Only ascending is supported for this field
  collection.order(name: :asc) if ascending
end
```

Requesting `sort: "-name"` will raise:
```
The articles collection can not be sorted by '-name'
```

This is useful when descending order is expensive or semantically meaningless for a given field.

#### Default sort

Use `default_sort` to apply a fallback when no `sort` param is provided. It accepts either a sort string (which delegates through the same `sortable_by` pipeline) or a no-argument block:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do
    collection.map { |article| ArticleSerializer.new(article) }
  end

  sortable_by :title do |ascending|
    collection.order(title: ascending ? :asc : :desc)
  end

  # Delegates to the :title sortable_by block, descending
  default_sort "-title"

  # Or provide a custom fallback block (no arguments)
  # default_sort { collection.order(created_at: :desc) }
end
```

### Filtering collections

Declare filter fields on a collection serializer with `filterable_by`. The block receives the value from the `filter` param and must return the filtered collection, or `nil` to signal that the value is invalid:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do
    collection.map { |article| ArticleSerializer.new(article) }
  end

  filterable_by :name do |value|
    collection.where(name: value)
  end

  filterable_by :published do |value|
    collection.where(published: value == "true")
  end
end
```

Pass the `filter:` option as a hash at render time:

```ruby
# Filter by a single field
ArticlesSerializer.new(Article.all, filter: { name: "Alice" }).render

# Filter by multiple fields — applied as AND logic, left to right
ArticlesSerializer.new(Article.all, filter: { name: "Alice", published: "true" }).render
```

Requesting a key that has not been declared with `filterable_by` raises `Halitosis::InvalidFilterParameter`, which Rails maps to a `400 Bad Request` response.

#### Rejecting invalid values

Return `nil` from a `filterable_by` block to signal that the provided value cannot be applied. Halitosis will raise `InvalidFilterParameter` naming the field, without reflecting the user-supplied value back in the message:

```ruby
filterable_by :created_after do |date_str|
  date = DateTime.parse(date_str) rescue nil
  collection.created_after(date) if date
end
```

Providing an unparseable date string will raise:
```
The articles collection can not be filtered by 'created_after' with the provided value
```

#### Nested filter keys

Both Rails bracket notation (`filter[user][name]=Alice`) and dot notation
(`filter[user.name]=Alice`) produce the same dot-separated key after parsing,
so a single `filterable_by` declaration handles both:

```ruby
filterable_by :"user.name" do |value|
  collection.joins(:user).where(users: { name: value })
end
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
# => { article: { id: 1, title: "Hello World", _type: "article" } }
```

### Relationships

Relationships allow embedding associated serializers inside `_relationships`. They are **opt-in**: they are only rendered when explicitly requested.

One-to-one:

```ruby
relationship(:author) { UserSerializer.new(article.author) }
# => { article: { ..., _relationships: { author: { id: 5, name: "Alice", _type: "user" } } } }
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
#        _type: "article",
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
#        _type: "article",
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

### Collecting includes (JSON:API-style sideloading)

Include `collect_includes` in a serializer to hoist included relationships out of the nested `_relationships` structure and into a flat top-level `included` array, deduplicating by type and id. This mirrors the [JSON:API compound document](https://jsonapi.org/format/#document-compound-documents) pattern.

```ruby
class ArticleSerializer
  include Halitosis
  include Halitosis::Relationships

  resource :article

  collect_includes            # enable sideloading on this serializer

  identifier :id
  attribute :title

  relationship(:author) { AuthorSerializer.new(article.author) }
end
```

When a relationship is included, the child serializer's full payload is placed in `included` and a stub (id + `_type`) is left inline:

```ruby
ArticleSerializer.new(article, include: "author").render
# => {
#      article: {
#        id: 1,
#        title: "Hello World",
#        _type: "article",
#        _relationships: { author: { id: 5, _type: "author" } }
#      },
#      included: [
#        { id: 5, name: "Alice", _type: "author" }
#      ]
#    }
```

If no relationships are included, the `included` key is omitted entirely.

#### Deduplication

When multiple resources reference the same related object, it appears only once in `included`:

```ruby
class ArticlesSerializer
  include Halitosis
  include Halitosis::Relationships

  collect_includes

  collection :articles do
    collection.map { |article| ArticleSerializer.new(article) }
  end
end

ArticlesSerializer.new(articles, include: "author").render
# => {
#      articles: [
#        { id: 1, title: "First",  _type: "article", _relationships: { author: { id: 5, _type: "author" } } },
#        { id: 2, title: "Second", _type: "article", _relationships: { author: { id: 5, _type: "author" } } }
#      ],
#      included: [
#        { id: 5, name: "Alice", _type: "author" }   # appears once despite two references
#      ]
#    }
```

### Render options summary

| Option | Default | Description |
| --- | --- | --- |
| `include:` | `{}` | Relationships to include (hash, array, or string) |
| `sort:` | `nil` | Sort fields (string or array; prefix `-` for descending, e.g. `"name,-age"`) |
| `filter:` | `nil` | Filter key/value pairs as a hash, e.g. `{ name: "Alice" }` |
| `include_root:` | resource name | Override root key, or `false` to omit the wrapper |
| `include_links:` | `true` | Set to `false` to omit all `_links` |
| `include_meta:` | `true` | Set to `false` to omit all `_meta` |
| `include_permissions:` | `true` | Set to `false` to omit all `_permissions` |

```ruby
# Omit the root wrapper entirely
ArticleSerializer.new(article, include_root: false).render
# => { id: 1, title: "Hello World", _type: "article", ... }

# Use a custom root key
ArticleSerializer.new(article, include_root: "post").render
# => { post: { id: 1, title: "Hello World", _type: "article", ... } }
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

When using `renderable:`, Halitosis will automatically forward the `include`, `sort`, and `filter` query parameters from the request to the serializer, so clients can request relationships, ordering, and filtering via `?include=author&sort=-published_at&filter[name]=Alice` without any extra controller code.

#### Error handling

Include `Halitosis::ErrorHandling` in your base controller to automatically rescue `InvalidQueryParameter` errors (and its subclasses `InvalidSortParameter`, `InvalidIncludeParameter`, and `InvalidFilterParameter`) and render a structured `400 Bad Request` JSON response:

```ruby
class ApplicationController < ActionController::Base
  include Halitosis::ErrorHandling
end
```

Invalid `sort`, `filter`, or `include` parameters will now produce a response like:

```json
{
  "errors": [
    {
      "id": "invalid_sort_parameter",
      "title": "Invalid Sort Parameter",
      "detail": "The articles collection can not be sorted by 'nonexistent'",
      "source": { "parameter": "sort" }
    }
  ]
}
```

The `id` and `title` values come from Halitosis's built-in locale file (`en.halitosis.errors.{ClassName}.id` / `.title`). Override them in your application's locale file:

```yaml
# config/locales/en.yml
en:
  halitosis:
    errors:
      "Halitosis::InvalidSortParameter":
        title: "Unsupported Sort Field"
```

If you need custom rescue logic, `Halitosis::ParameterExceptionSerializer` is available directly:

```ruby
rescue_from Halitosis::InvalidQueryParameter do |error|
  render json: Halitosis::ParameterExceptionSerializer.new(error), status: :unprocessable_entity
end
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bmorrall/halitosis. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/bmorrall/halitosis/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Halitosis project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/bmorrall/halitosis/blob/main/CODE_OF_CONDUCT.md).
