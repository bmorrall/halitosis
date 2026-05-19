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
  attribute :title    # calls serializer#title if defined, otherwise article.title
end

ArticleSerializer.new(article).render
# => { article: { id: 1, title: "Hello World" } }
```

#### 3. Collection

Wraps a collection of items. Declare it with `collection`, providing a block that maps each item to a Halitosis serializer instance:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end
end

ArticlesSerializer.new(Article.all).render
# => { articles: [ { id: 1, title: "Hello World" }, ... ] }
```

### Sorting collections

Declare sort fields on a collection serializer with `sortable_by`. The block receives the current collection and a Boolean — `true` for ascending, `false` for descending — and must return the sorted collection:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  sortable_by :title do |collection, ascending|
    collection.order(title: ascending ? :asc : :desc)
  end

  sortable_by :published_at do |collection, ascending|
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
sortable_by :name do |collection, ascending|
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

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  sortable_by :title do |collection, ascending|
    collection.order(title: ascending ? :asc : :desc)
  end

  # Delegates to the :title sortable_by block, descending
  default_sort "-title"

  # Or provide a custom fallback block (no arguments)
  # default_sort { collection.order(created_at: :desc) }
end
```

### Filtering collections

Declare filter fields on a collection serializer with `filterable_by`. The block receives the current collection and the value from the `filter` param, and must return the filtered collection, or `nil` to signal that the value is invalid:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  filterable_by :name do |collection, value|
    collection.where(name: value)
  end

  filterable_by :published do |collection, value|
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
filterable_by :created_after do |collection, date_str|
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
so a single `filterable_by` declaration handles both.

Use a zero-arity block to open a namespace and group related filter fields under a shared prefix:

```ruby
filterable_by :user do
  filterable_by :name do |collection, value|
    collection.joins(:user).where(users: { name: value })
  end

  filterable_by :role do |collection, value|
    collection.joins(:user).where(users: { role: value })
  end
end
```

This registers `user.name` and `user.role` as filter fields. Both of the following are equivalent:

```ruby
# Rails bracket notation
ArticlesSerializer.new(Article.all, filter: { user: { name: "Alice" } }).render

# Dot notation
ArticlesSerializer.new(Article.all, filter: { "user.name" => "Alice" }).render
```

Namespaces can be nested to any depth. A block with no arguments opens a namespace; a block with one argument is a filter implementation. Any other arity raises `InvalidField` at class load time.

### Preloading collection includes

Use `allow_include` on a collection serializer to declare which include paths are accepted and attach a preload block that fires before the collection is rendered. This is the standard way to prevent N+1 queries when nested relationships are requested on a collection.

The block receives the current collection and must return the preloaded collection:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  allow_include(:author) { |coll| coll.includes(:author) }
end

ArticlesSerializer.new(Article.all, include: "author").render
```

The block fires before sorting, filtering, and pagination run, so the preloaded collection flows through the entire pipeline.

Omitting the block registers the path as allowed with no preload — the collection passes through unchanged:

```ruby
allow_include(:author)  # declaration only
```

#### Namespace block with nested paths

Use an arity-0 block to open a namespace. Inside it, use `preload` to attach a procedure for the parent path and nested `allow_include` calls to declare child paths:

```ruby
allow_include(:author) do
  preload ->(coll) { coll.includes(:author) }
  allow_include(:avatar)  { |coll| coll.includes(author: :avatar) }
  allow_include(:summary) { |coll| coll.includes(author: :summary) }
end
```

The preload walk fires the **deepest** matching block for each requested leaf path. When `include: "author.avatar"` is requested, only the `:avatar` block fires. When `include: "author"` alone is requested, the `preload` block fires. Each block fires at most once per render, even when multiple leaves share the same ancestor.

Namespaces can be nested to any depth:

```ruby
allow_include(:author) do
  allow_include(:publications) do
    preload ->(coll) { coll.includes(author: :publications) }
    allow_include(:journal) { |coll| coll.includes(author: { publications: :journal }) }
  end
end
```

### Pagination

Declare server-side pagination on a collection serializer with `paginate_by_page`. The block receives the current `collection`, the resolved `number` (page number), and `size` (items per page), and must return the paginated collection, or `nil` to signal that the values are invalid:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  paginate_by_page :kaminari, default_page_size: 25 do |collection, number, size|
    collection.page(number).per(size)
  end
end
```

Pagination is controlled by a nested `page:` hash following the [JSON:API recommendation](https://jsonapi.org/format/#fetching-pagination):

| Key | Default | Description |
| --- | --- | --- |
| `page[:number]` | `1` | 1-based page number |
| `page[:size]` | `default_page_size` | Items per page |

```ruby
# First page with default size
ArticlesSerializer.new(Article.all).render

# Second page
ArticlesSerializer.new(Article.all, page: { number: 2 }).render

# Custom page size
ArticlesSerializer.new(Article.all, page: { number: 1, size: 10 }).render
```

When using `render_with_params` (the Rails integration helper), both the JSON:API bracket style (`page[number]`/`page[size]`) and the legacy flat style (`page`/`per_page`) are accepted as query parameters.

If `page[:number]` or `page[:size]` cannot be coerced to an integer, or the block returns `nil`, an `InvalidPaginationParameter` is raised (mapped to `400 Bad Request` by the Rails integration).

#### Pagination adapter

The adapter tells Halitosis how to read page metadata from the paginated collection. Set a global default in an initializer:

```ruby
Halitosis.configure { |c| c.pagination_adapter = :kaminari }
```

Or pass the adapter symbol as the first argument to `paginate_by_page` or `paginate_with`:

```ruby
paginate_by_page :will_paginate, default_page_size: 25 do |collection, number, size|
  collection.paginate(page: number, per_page: size)
end
```

Built-in adapters: `:kaminari`, `:will_paginate`. Any callable that accepts the paginated collection and returns `{ current_page:, total_pages:, prev_page:, next_page: }` also works.

#### Pagy

Use `paginate_with_pagy` instead of `paginate_by_page` when using Pagy. Pagy returns a separate metadata object alongside the records; `paginate_with_pagy` handles both automatically:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  paginate_with_pagy
end
```

With no block, `paginate_with_pagy` reads page number and size from the render context automatically. When no `page[:size]` is provided, Pagy uses its own global default (`Pagy::DEFAULT[:limit]`).

If you need to supply extra options to `Pagy::Offset.new` (e.g. a custom count or limit), pass a block that receives `context`, `collection`, and `page_params` and returns a kwargs hash:

```ruby
paginate_with_pagy do |collection, page_params|
  { limit: 5 }
end
```

Filters and sorts declared on the serializer are still applied to the collection before pagination runs, keeping the full pipeline intact.

### Pagination links

Use `paginate_links` to emit `self`/`first`/`last`/`prev`/`next` links alongside a paginated collection. The block receives the target page number and the active `query_params` hash (including sort, filter, and page size):

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do
    collection.map { |article| ArticleSerializer.new(article) }
  end

  paginate_by_page :kaminari, default_page_size: 25 do |collection, number, size|
    collection.page(number).per(size)
  end

  paginate_links do |page_number, query_params|
    articles_url(query_params.merge(page: { number: page_number }))
  end
end
```

All five keys (`self`, `first`, `last`, `prev`, `next`) are always present in `_links` as Link Objects with an `href` key. `self` points to the current page. Unavailable links — `prev` on the first page and `next` on the last — are emitted as `null`.

Pass `only:` to limit which keys are emitted:

```ruby
paginate_links only: %i[self next] do |page_number, query_params|
  articles_url(query_params.merge(page: { number: page_number }))
end
```

```json
{
  "articles": [...],
  "_links": {
    "self":  { "href": "/articles?page[number]=1" },
    "first": { "href": "/articles?page[number]=1" },
    "last":  { "href": "/articles?page[number]=5" },
    "prev":  null,
    "next":  { "href": "/articles?page[number]=2" }
  }
}
```

`paginate_links` must be declared after the pagination method (`paginate_by_page`, `paginate_with`, or `paginate_with_pagy`).

### Pagination meta

Use `paginate_meta` to emit `self`, `first`, `last`, `prev`, and `next` page numbers as root-level `_meta` keys. Unlike `paginate_links`, no block is required — the values are emitted directly from the pagination adapter:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  paginate_by_page :kaminari, default_page_size: 25 do |collection, number, size|
    collection.page(number).per(size)
  end

  paginate_meta
end
```

This produces a `_meta` hash at the root level:

```json
{
  "articles": [...],
  "_meta": { "self": 2, "first": 1, "last": 5, "prev": 1, "next": 3 }
}
```

All five keys are always present. Unavailable page numbers (`prev` on the first page, `next` on the last) are emitted as `null`.

Pass `only:` to emit a custom subset of keys. The full available pool also includes `current_page`, `per_page`, `total_entries`, and `total_pages`:

```ruby
paginate_meta only: %i[current_page total_pages]
```

`paginate_meta` must be declared after the pagination method (`paginate_by_page`, `paginate_with`, or `paginate_with_pagy`).

`paginate_meta` and `paginate_links` may be declared together on the same serializer. In that case both `_links` (URLs) and `_meta` (page numbers) are emitted. `paginate_meta` also merges with any other `root_meta` fields on the serializer.

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
# Calls serializer#title if defined, otherwise delegates to the resource
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

#### Profile link

Use `profile` to declare a [HAL profile](https://datatracker.ietf.org/doc/html/draft-kelly-json-hal-11#section-5.6) link pointing to documentation for the resource type (e.g. your API docs):

```ruby
class ArticleSerializer
  include Halitosis

  profile "https://docs.example.com/resources/articles"

  resource :article
end
```

This adds a `profile` entry to `_links`:

```json
{
  "article": {
    "_links": {
      "self": { "href": "/articles/1" },
      "profile": { "href": "https://docs.example.com/resources/articles" }
    }
  }
}
```

The profile link is only emitted when the serializer is rendered as the root resource. It is suppressed when the serializer appears as a nested relationship inside another serializer.

For collection serializers, `profile` adds the link to the root-level `_links`:

```ruby
class ArticlesSerializer
  include Halitosis

  profile "https://docs.example.com/resources/articles"

  collection :articles do
    collection.map { |a| ArticleSerializer.new(a) }
  end
end
```

### Relationships

Relationships allow embedding associated serializers inside `_relationships`. They are **opt-in**: they are only rendered when explicitly requested.

One-to-one:

```ruby
relationship(:author, preload: true) { |author| UserSerializer.new(author) }
# => { article: { ..., _relationships: { author: { id: 5, name: "Alice" } } } }
```

One-to-many (array of serializers):

```ruby
relationship(:comments, preload: true) do |comments|
  comments.map { |comment| CommentSerializer.new(comment) }
end
# => { article: { ..., _relationships: { comments: [ ... ] } } }
```

One-to-many (collection serializer):

```ruby
relationship(:comments, preload: true) { |comments| CommentsSerializer.new(comments) }
```

The `rel` method is a shorthand alias for `relationship`:

```ruby
rel(:author) { UserSerializer.new(article.author) }
rel(:comments) { article.comments.map { |c| CommentSerializer.new(c) } }
```

#### Relationship links

Pass `link:` to declare a HAL link alongside the relationship. The link appears in `_links` unconditionally — even when the relationship itself is not included. This lets clients discover the URL for a relationship without having to request the full nested payload.

```ruby
relationship(:author, link: -> { author_path(resource[:author_id]) }) do
  UserSerializer.new(resource[:author])
end
```

Output without `include: :author`:

```json
{
  "article": {
    "_links": { "author": { "href": "/people/5" } }
  }
}
```

Output with `include: :author`:

```json
{
  "article": {
    "_links": { "author": { "href": "/people/5" } },
    "_relationships": { "author": { "name": "Alice" } }
  }
}
```

A static string can be used when the URL does not depend on the resource:

```ruby
relationship(:docs, link: "/docs/articles") { nil }
```

The `link:` value respects the same `if:` / `unless:` guards as the relationship itself — if the relationship is hidden, the link is hidden too:

```ruby
relationship(:author, if: :can_view_author?, link: -> { author_path(resource[:author_id]) }) do
  UserSerializer.new(resource[:author])
end
```

When `preload:` is also set, a 1-arity lambda passed to `link:` receives the preloaded value — the same value delivered to the relationship block. This avoids a second lookup just to build the URL:

```ruby
relationship(:author, preload: true, link: ->(author) { "/people/#{author.id}" }) do |author|
  UserSerializer.new(author)
end

def author
  article.author # called once; result shared by the link and the relationship block
end
```

A 0-arity lambda continues to work as before when the URL does not depend on the preloaded value:

```ruby
relationship(:author, preload: true, link: -> { "/people" }) do |author|
  UserSerializer.new(author)
end
```


#### Preloading relationship values

Use `preload: true` to call a method matching the relationship name once and cache the result for the duration of the render. The cached value is passed as the first argument to the relationship block:

```ruby
relationship(:author, preload: true) do |author|
  UserSerializer.new(author)
end

def author
  article.author # called once, result cached
end
```

Use a Symbol or String to cache under a different key — useful when multiple relationships share the same preloaded data:

```ruby
rel(:author,       preload: :author_data) { |data| UserSerializer.new(data) }
rel(:author_links, preload: :author_data) { |data| data.links }

def author_data
  article.author # evaluated once, shared between both relationships
end
```

Use `preload: false` to opt out. Any value manually stored under the field name is still used, but no method will be called automatically:

```ruby
relationship(:author, preload: false) { UserSerializer.new(article.author) }
```

#### Preloading nested includes

When a relationship exposes deeply nested associations, use `allow_include` to declare which nested paths are supported and how to enrich the preload cache when those paths are requested. This prevents N+1 queries as the render walks into nested relationships.

`allow_include` takes a top-level relationship name and a builder block. Each nested `allow_include` declaration accepts an arity-1 block that receives the current cached preload value and returns the enriched one:

```ruby
class ArticleSerializer
  include Halitosis

  resource :article

  relationship :author, preload: true do |author|
    UserSerializer.new(author)
  end

  allow_include :author do
    allow_include(:avatar)  { |author| author.includes(:avatar) }
    allow_include(:summary) { |author| author.includes(:summary) }
  end

  def author
    article.author
  end
end
```

When `include: "author.avatar"` is requested, the `:avatar` procedure is called with the cached `:author` value and its return value replaces it in the preload cache for the duration of the render. The relationship block then receives the enriched value.

Procedures compose: if `include: "author.avatar,author.summary"` is requested, both procedures run in turn on the same cached value.

When a builder node is itself a potential leaf (i.e. the deepest requested path), call `preload` inside the block to register its procedure:

```ruby
allow_include :author do
  allow_include(:publications) do
    preload ->(v) { v.includes(:publications) }
    allow_include(:journal) { |v| v.includes(publications: :journal) }
  end
end
```

Omitting the block on a nested `allow_include` registers it as a pass-through — the cached value is returned unchanged:

```ruby
allow_include :author do
  allow_include(:avatar)  # declaration only, no preload enrichment
end
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

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  root_link(:self) { "/articles" }
  root_link(:next, :templated) { "/articles?page={?page}" }

  root_meta(:total) { raw_collection.total_count }
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

#### Generating links with `query_params`

When a `root_link` (or `link`) block accepts one argument, it receives the accumulated `query_params` hash — a plain hash of the normalised request params that were active during that render. Each middleware module contributes its slice:

| Key | Contributed by | Shape |
| --- | --- | --- |
| `filter:` | `filterable_by` | Symbolised hash, e.g. `{ name: "Alice" }` |
| `sort:` | `sortable_by` | Reconstructed string, e.g. `"title,-published_at"` |
| `page:` | `paginate_by_page` | `{ number: Integer, size: Integer }` (always includes defaults) |
| `include:` | all serializers | Comma-separated string, e.g. `"author,comments"` |

Pass `query_params` directly to a Rails URL helper so that self and pagination links automatically reflect the active filter, sort, and page state:

```ruby
class ArticlesSerializer
  include Halitosis

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end

  filterable_by :name do |value|
    collection.where(name: value)
  end

  sortable_by :published_at do |ascending|
    collection.order(published_at: ascending ? :asc : :desc)
  end

  paginate_by_page default_page_size: 25 do |collection, number, size|
    collection.page(number).per(size)
  end

  # On collections, `link` is an alias for `root_link`
  link(:self) do |query_params|
    articles_url(query_params)
  end

  root_link(:first) do |query_params|
    articles_url(query_params.merge(page: { number: 1, size: query_params.dig(:page, :size) }))
  end
end
```

When rendered with `filter: { name: "Alice" }, sort: "-published_at", page: { number: 2, size: 10 }`, the `self` link will be:

```
/articles?filter[name]=Alice&sort=-published_at&page[number]=2&page[size]=10
```

Resource serializers support the same convention. When `include:` is passed, it appears in `query_params`:

```ruby
class ArticleSerializer
  include Halitosis

  resource :article

  identifier :id
  attribute :title

  relationship(:author) { AuthorSerializer.new(article.author) }

  root_link(:self) do |query_params|
    query_string = query_params.map { |k, v| "#{k}=#{v}" }.join("&")
    "/articles/#{article.id}?#{query_string}"
  end
end

ArticleSerializer.new(article, include: "author").render[:_links]
# => { self: { href: "/articles/1?include=author" } }
```

If you need access to both the full render context and `query_params`, use a two-argument block:

```ruby
root_link(:self) do |context, query_params|
  # context is the frozen render-time context; query_params is context.query_params
  query_string = query_params.map { |k, v| "#{k}=#{v}" }.join("&")
  "/articles?#{query_string}"
end
```

Keys for middleware that was not triggered (e.g. no `filter` param, or no `paginate_by_page` declaration) are omitted entirely. The `sort:` key is also omitted when a block-based `default_sort` is in effect, since it cannot be reconstructed as a param string. The hash is frozen — use `merge` to build variations of it.

### Collecting includes (JSON:API-style sideloading)

Include `collect_includes!` in a serializer to hoist included relationships out of the nested `_relationships` structure and into a top-level `included` hash, grouped by resource type and deduplicated by id. This mirrors the [JSON:API compound document](https://jsonapi.org/format/#document-compound-documents) pattern.

```ruby
class ArticleSerializer
  include Halitosis

  resource :article

  collect_includes!           # enable sideloading on this serializer

  identifier :id
  attribute :title

  relationship(:author) { AuthorSerializer.new(article.author) }
end
```

When a relationship is included, the child serializer's full payload is placed in `included` and a typed stub (`{id:, _type:}`) is left inline:

```ruby
ArticleSerializer.new(article, include: "author").render
# => {
#      article: {
#        id: 1,
#        title: "Hello World",
#        _relationships: { author: { id: 5, _type: "author" } }
#      },
#      included: {
#        author: [
#          { id: 5, name: "Alice" }
#        ]
#      }
#    }
```

If no relationships are included, the `included` key is omitted entirely.

#### Deduplication

When multiple resources reference the same related object, it appears only once in `included`:

```ruby
class ArticlesSerializer
  include Halitosis

  collect_includes!

  collection :articles do |collection|
    collection.map { |article| ArticleSerializer.new(article) }
  end
end

ArticlesSerializer.new(articles, include: "author").render
# => {
#      articles: [
#        { id: 1, title: "First",  _relationships: { author: { id: 5, _type: "author" } } },
#        { id: 2, title: "Second", _relationships: { author: { id: 5, _type: "author" } } }
#      ],
#      included: {
#        author: [
#          { id: 5, name: "Alice" }   # appears once despite two references
#        ]
#      }
#    }
```

### Render options summary

| Option | Default | Description |
| --- | --- | --- |
| `include:` | `{}` | Relationships to include (hash, array, or string) |
| `sort:` | `nil` | Sort fields (string or array; prefix `-` for descending, e.g. `"name,-age"`) |
| `filter:` | `nil` | Filter key/value pairs as a hash, e.g. `{ name: "Alice" }` |
| `page:` | `{}` | Pagination hash with optional `number:` (1-based) and `size:` keys |
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
        id: "unsupported_sort_field"
        title: "Unsupported Sort Field"
```

If you need custom rescue logic, `Halitosis::ParameterExceptionSerializer` is available directly:

```ruby
rescue_from Halitosis::InvalidQueryParameter do |error|
  render json: Halitosis::ParameterExceptionSerializer.new(error), status: :unprocessable_entity
end
```


## Configuration

Configure Halitosis via an initializer:

```ruby
Halitosis.configure do |config|
  # Modules to include in every serializer class
  config.extensions = [MyLoggingExtension]

  # Default adapter used when paginating with paginate_by_page or paginate_with.
  # Accepted values: :kaminari, :will_paginate, or any callable.
  config.pagination_adapter = :kaminari
end
```

| Option | Default | Description |
| --- | --- | --- |
| `extensions` | `[]` | Modules included in every serializer class at load time |
| `pagination_adapter` | `nil` | Default adapter for pagination metadata — `:kaminari`, `:will_paginate`, or a callable |
| `collect_includes` | `false` | When `true`, enables JSON:API-style sideloading on every serializer (equivalent to calling `collect_includes!` on each) |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bmorrall/halitosis. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/bmorrall/halitosis/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Halitosis project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/bmorrall/halitosis/blob/main/CODE_OF_CONDUCT.md).
