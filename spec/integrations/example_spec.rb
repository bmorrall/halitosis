# frozen_string_literal: true

class Duck
  def id = 1

  def first_name = "Ferdie"

  def last_name = "Duck"
end

# Example of a straightforward Halitosis serializer with a resource
#
class DuckSerializer
  include Halitosis

  resource :duck

  def id = duck.id

  # == 1. Properties
  #
  # If you define a property without an explicit value or proc, Halitosis will
  # look for a public instance method with the corresponding name.
  #
  # This will call DuckSerializer#id.
  #
  property :id # => { id: 1 }

  # You can also define a property with an explicit value, e.g.:
  #
  property :age, value: 9.2 # => { age: 9.2 }

  # Or you can use a proc to determine the property value at render time.
  #
  # The example below could also be written: property(:full_name) { ... }
  #
  property :full_name do # => { full_name: 'Ferdie Duck' }
    "#{duck.first_name} #{duck.last_name}"
  end

  # == 2. Links
  #
  # As with properties, links can be defined with a proc:
  #
  link :self do
    "/ducks/#{id}" # => { self: { href: '/ducks/1' } }
  end

  # ...Or with an explicit value:
  #
  link :root, value: "/ducks" # => { root: { href: '/ducks' } }

  # Links can also be defined as "templated", following HAL+JSON conventions:
  #
  link :find, :templated do # => ... { href: '/ducks/{?id}', templated: true }
    "/ducks/{?id}"
  end

  # If Halitosis is loaded in a Rails application, url helpers will be available
  # automatically:
  #
  # link(:new) { new_duck_path }

  # == 3. Relationships
  #
  # Relationship resources are not rendered by default. They will be included if
  # both of the following conditions are met:
  #
  # 1. The proc returns either a Halitosis instance or an array of Halitosis instances
  # 2. The relationship is requested via the parent serializer's options, e.g.:
  #
  #      DuckSerializer.new(include: { ducklings: true, parents: false })
  #
  rel :ducklings do # => { ducklings: <DuckKidsSerializer#render> }
    DuckKidsSerializer.new
  end

  rel :parents do # => will not be included according to example options above
    DucksSerializer.new([duck, duck])
  end

  # Included resources can be nested to any depth, e.g.:
  #
  # DuckSerializer.new(included: {
  #   ducklings: {
  #     foods: {
  #       ingredients: true
  #     },
  #     enclosure: true
  #   }
  # })
end

# Another simple serializer to demonstrate resources above
#
class DuckKidsSerializer
  include Halitosis

  property :name, value: "Duckies"

  property :count, value: 5

  meta :quacks_per_minute, value: "many"
end

class DucksSerializer
  include Halitosis

  collection :ducks do
    collection.map { |duck| DuckSerializer.new(duck) }
  end

  permission :quack, value: true
end

RSpec.describe "Halitosis Example" do
  specify { expect(DuckSerializer.resource_name).to eq "duck" }

  it "renders a Duck" do
    rendered = DuckSerializer.new(Duck.new).render

    expect(rendered).to eq(
      duck: {
        id: 1,
        age: 9.2,
        full_name: "Ferdie Duck",
        _links: {
          self: {href: "/ducks/1"},
          root: {href: "/ducks"},
          find: {href: "/ducks/{?id}", templated: true}
        }
      }
    )
  end

  it "renders a Duck with a custom root name" do
    rendered = DuckSerializer.new(Duck.new, include_root: "mallard").render

    expect(rendered).to eq(
      mallard: {
        id: 1,
        age: 9.2,
        full_name: "Ferdie Duck",
        _links: {
          self: {href: "/ducks/1"},
          root: {href: "/ducks"},
          find: {href: "/ducks/{?id}", templated: true}
        }
      }
    )
  end

  it "renders a Duck without a root" do
    rendered = DuckSerializer.new(Duck.new, include_root: false).render

    expect(rendered).to eq(
      id: 1,
      age: 9.2,
      full_name: "Ferdie Duck",
      _links: {
        self: {href: "/ducks/1"},
        root: {href: "/ducks"},
        find: {href: "/ducks/{?id}", templated: true}
      }
    )
  end

  it "renders a Duck without links" do
    rendered = DuckSerializer.new(Duck.new, include_links: false).render

    expect(rendered).to eq(
      duck: {
        id: 1,
        age: 9.2,
        full_name: "Ferdie Duck"
      }
    )
  end

  it "renders a Duck with included ducklings" do
    rendered = DuckSerializer.new(Duck.new, include: {ducklings: true}).render

    expect(rendered).to eq(
      duck: {
        id: 1,
        age: 9.2,
        full_name: "Ferdie Duck",
        _relationships: {
          ducklings: {
            name: "Duckies",
            count: 5,
            _meta: {quacks_per_minute: "many"}
          }
        },
        _links: {
          self: {href: "/ducks/1"},
          root: {href: "/ducks"},
          find: {href: "/ducks/{?id}", templated: true}
        }
      }
    )
  end

  it "renders a duck with included ducklings with an include param as strings" do
    rendered = DuckSerializer.new(Duck.new, include: "ducklings").render

    expect(rendered).to eq(
      duck: {
        id: 1,
        age: 9.2,
        full_name: "Ferdie Duck",
        _relationships: {
          ducklings: {
            name: "Duckies",
            count: 5,
            _meta: {quacks_per_minute: "many"}
          }
        },
        _links: {
          self: {href: "/ducks/1"},
          root: {href: "/ducks"},
          find: {href: "/ducks/{?id}", templated: true}
        }
      }
    )
  end

  it "renders a collection of Ducks" do
    ducks = [Duck.new, Duck.new]

    rendered = DucksSerializer.new(ducks).render

    expect(rendered).to eq(
      ducks: [
        {
          id: 1,
          age: 9.2,
          full_name: "Ferdie Duck",
          _links: {
            self: {href: "/ducks/1"},
            root: {href: "/ducks"},
            find: {href: "/ducks/{?id}", templated: true}
          }
        },
        {
          id: 1,
          age: 9.2,
          full_name: "Ferdie Duck",
          _links: {
            self: {href: "/ducks/1"},
            root: {href: "/ducks"},
            find: {href: "/ducks/{?id}", templated: true}
          }
        }
      ],
      _permissions: {
        quack: true
      }
    )
  end

  it "renders a collection of Ducks with included ducklings" do
    ducks = [Duck.new, Duck.new]

    rendered = DucksSerializer.new(ducks, include: {ducks: {ducklings: true}}).render

    expect(rendered).to eq(
      ducks: [
        {
          id: 1,
          age: 9.2,
          full_name: "Ferdie Duck",
          _relationships: {
            ducklings: {
              name: "Duckies",
              count: 5,
              _meta: {quacks_per_minute: "many"}
            }
          },
          _links: {
            self: {href: "/ducks/1"},
            root: {href: "/ducks"},
            find: {href: "/ducks/{?id}", templated: true}
          }
        },
        {
          id: 1,
          age: 9.2,
          full_name: "Ferdie Duck",
          _relationships: {
            ducklings: {
              name: "Duckies",
              count: 5,
              _meta: {quacks_per_minute: "many"}
            }
          },
          _links: {
            self: {href: "/ducks/1"},
            root: {href: "/ducks"},
            find: {href: "/ducks/{?id}", templated: true}
          }
        }
      ],
      _permissions: {
        quack: true
      }
    )
  end

  it "renders a collection with a custom root name" do
    ducks = [Duck.new]

    rendered = DucksSerializer.new(ducks, include_root: "mallards").render

    expect(rendered).to eq(
      mallards: [
        {
          id: 1,
          age: 9.2,
          full_name: "Ferdie Duck",
          _links: {
            self: {href: "/ducks/1"},
            root: {href: "/ducks"},
            find: {href: "/ducks/{?id}", templated: true}
          }
        }
      ],
      _permissions: {
        quack: true
      }
    )
  end

  it "renders a collection without a root but without additional fields" do
    ducks = [Duck.new]

    rendered = DucksSerializer.new(ducks, include_root: false).render

    expect(rendered).to eq(
      [
        {
          id: 1,
          age: 9.2,
          full_name: "Ferdie Duck",
          _links: {
            self: {href: "/ducks/1"},
            root: {href: "/ducks"},
            find: {href: "/ducks/{?id}", templated: true}
          }
        }
      ]
    )
  end

  it "renders a collection of Ducks with parents" do
    ducks = [Duck.new]

    rendered = DucksSerializer.new(ducks, include: {ducks: {parents: true}}).render

    expect(rendered).to eq(
      ducks: [
        {
          id: 1,
          age: 9.2,
          full_name: "Ferdie Duck",
          _links: {
            self: {href: "/ducks/1"},
            root: {href: "/ducks"},
            find: {href: "/ducks/{?id}", templated: true}
          },
          _relationships: {
            parents: [
              {
                id: 1,
                age: 9.2,
                full_name: "Ferdie Duck",
                _links: {
                  self: {href: "/ducks/1"},
                  root: {href: "/ducks"},
                  find: {href: "/ducks/{?id}", templated: true}
                }
              },
              {
                id: 1,
                age: 9.2,
                full_name: "Ferdie Duck",
                _links: {
                  self: {href: "/ducks/1"},
                  root: {href: "/ducks"},
                  find: {href: "/ducks/{?id}", templated: true}
                }
              }
            ]
          }
        }
      ],
      _permissions: {
        quack: true
      }
    )
  end

  it "renders a collection of Ducks with parents and parents with ducklings" do
    ducks = [Duck.new]

    rendered = DucksSerializer.new(ducks, include: {ducks: {parents: {ducklings: true}}}).render

    expect(rendered).to eq(
      ducks: [
        {
          id: 1,
          age: 9.2,
          full_name: "Ferdie Duck",
          _links: {
            self: {href: "/ducks/1"},
            root: {href: "/ducks"},
            find: {href: "/ducks/{?id}", templated: true}
          },
          _relationships: {
            parents: [
              {
                id: 1,
                age: 9.2,
                full_name: "Ferdie Duck",
                _links: {
                  self: {href: "/ducks/1"},
                  root: {href: "/ducks"},
                  find: {href: "/ducks/{?id}", templated: true}
                },
                _relationships: {
                  ducklings: {
                    name: "Duckies",
                    count: 5,
                    _meta: {quacks_per_minute: "many"}
                  }
                }
              },
              {
                id: 1,
                age: 9.2,
                full_name: "Ferdie Duck",
                _links: {
                  self: {href: "/ducks/1"},
                  root: {href: "/ducks"},
                  find: {href: "/ducks/{?id}", templated: true}
                },
                _relationships: {
                  ducklings: {
                    name: "Duckies",
                    count: 5,
                    _meta: {quacks_per_minute: "many"}
                  }
                }
              }
            ]
          }
        }
      ],
      _permissions: {
        quack: true
      }
    )
  end
end
