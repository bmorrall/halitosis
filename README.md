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

### Basic usage

Create a simple serializer class and include Halitosis:

```ruby
class Duck
  def name = "Ferdi"
  def code = "ferdi"
end

class DuckSerializer
  include Halitosis

  resource :duck

  property :name

  link :self do
    "/ducks/#{duck.code}"
  end
end
```

Instantiate:

```ruby
duck = Duck.new
serializer = DuckSerializer.new(duck)
```

Then call `serializer.render`:

```ruby
{
  duck: {
    name: 'Ferdi',
    _links: {
      self: { href: '/ducks/ferdi' }
    }
  }
}
```

Or `serializer.to_json`:

```ruby
'{"duck": {"name": "Ferdi", "_links": {"self": {"href": "/ducks/ferdi"}}}}'
```


### Serializer types

#### 1. Simple

Not associated with any particular resource or collection. For example, an API
entry point:

```ruby
class ApiRootSerializer
  include Halitosis

  link(:self) { '/api' }
end
```

#### 2. Resource

Represents a single item:

```ruby
class DuckSerializer
  include Halitosis

  resource :duck
end
```

When a resource is declared, `#initialize` expects the resource as the first argument:

```ruby
serializer = DuckSerializer.new(Duck.new, ...)
```

This makes property definitions cleaner:

```ruby
property :name # now calls Duck#name by default
```

#### 3. Collection

Represents a collection of items. When a collection is declared, `#initialize` expects the collection as the first argument:

```ruby
class DuckKidsSerializer
  include Halitosis

  collection :ducklings do
    [ ... ]
  end
end
```

The block should return an array of Halitosis instances in order to be rendered.

### Defining properties, links, relationships, meta, and permissions

Properties can be defined in several ways:

```ruby
property(:quacks) { "#{duck.quacks} per minute" }
```

```ruby
property :quacks # => Duck#quacks, if resource is declared
```

```ruby
property :quacks do
  duck.quacks.round
end
```

```ruby
property(:quacks) { calculate_quacks }

def calculate_quacks
  ...
end
```

#### Conditionals

The inclusion of properties can be determined by conditionals using `if` and
`unless` options. For example, with a method name:

```ruby
property :quacks, if: :include_quacks?

def include_quacks?
  duck.quacks < 10
end
```

With a proc:
```ruby
property :quacks, unless: proc { duck.quacks.nil? }, value: ...
```

For links and relationships:

```ruby
link :ducklings, :templated, unless: :exclude_ducklings_link?, value: ...
```

```ruby
relationship :ducklings, if: proc { duck.ducklings.size > 0 } do
  [ ... ]
end
```

#### Links

Simple link:

```ruby
link(:root) { '/' }
# => { _links: { root: { href: '/' } } ... }
```

Templated link:

```ruby
link(:find, :templated) { '/ducks/{?id}' }
# => { _links: { find: { href: '/ducks/{?id}', templated: true } } ... }
```

Optional links:

```ruby
serializer = MySerializerWithManyLinks.new(include_links: false)
rendered = serializer.render
rendered[:_links] # nil
```

#### Relationships

Simple one-to-one relationship:

```ruby
relationship(:owner) { UserSerializer.new(duck.owner) }
# => { duck: { _relationships: { owner: { ... } } } }
```

or a one-to-many collection with an array of record serializers:

```ruby
relationship(:ducklings) do
  duck.ducklings.map { |duckling| DucklingSerializer.new(duckling) }
end
# => { duck: { _relationships: { ducklings: [ ... ] } } }
```

or with a single collection serializer:

```ruby
relationship(:ducklings) do
  DucklingsSerializer.new(duck.ducklings)
end
```

A rel shorthand is also available for those who like to avoid a relationship:

```ruby
rel(:parent) { UserSerializer.new(...) }
rel(:ducklings) { [DucklingSerializer.new(...), ...] }
end
```

Resources are not rendered by default. They will be included if both
of the following conditions are met:

1. The proc returns either a Halitosis instance or an array of Halitosis instances
2. The relationship is requested via the parent serializer's options, e.g.:

```ruby
DuckSerializer.new(include: { ducklings: true, parent: false })
```

They can also be prested as an array of strings:

```ruby
DuckSerializer.new(include: ["ducklings", "parent"])
```

or as comma-joined strings:

```ruby
DuckSerializer.new(include: "ducklings,parent")
```

Resources can be nested to any depth, e.g.:

```ruby
DuckSerializer.new(include: {
  ducklings: {
    foods: {
      ingredients: true
    },
    pond: true
  }
})
```

or:

```ruby
DuckSerializer.new(include: "ducklings.foods.ingredients,ducklings.pond")
```

and requested on collections:

```ruby
DucksSerializer.new(..., include: ["ducks.ducklings.foods"])
```

#### Meta

Simple nested Meta information. Use this for providing details of attributes that are not modified directly by the API.

```ruby
meta(:created_at)
# => { _meta: { created_at: "2024-09-30T20:46:00Z }}
```

#### Permissions

Simple nested Access Rights information. Use this for informing clients of what resources they are able to access.

```ruby
permission(:snuggle) -> { duckling_policy.snuggle? }
# => { _permissions: { snuggle: true }}
```


### Using with Rails

If Halitosis is loaded in a Rails application, Rails url helpers will be
available in serializers:

```ruby
link(:new) { new_duck_url }
```

Serializers can either be passed in as a json argument to render:

```ruby
render json: DuckSerializer.new(duck)
```

or directly given as arguments to render:

```ruby
render DuckSerializer.new(duck)
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
