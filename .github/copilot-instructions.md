# Copilot Instructions

## Serializer immutability

Serializer instances are immutable after `initialize`. Do not read or write instance variables during rendering:

```ruby
# Correct — pass state through the context
def apply_sorts!(context)
  context.collection = sorted(context.collection)
end

# Incorrect — mutates the serializer instance
def apply_sorts!(context)
  @collection = sorted(@collection)
end
```

All mutable render-time state belongs on the `Context` object (or `CollectionContext` for collection serializers), not on the serializer instance.

## Raise calls

Always add a blank line after a `raise`, a call to a method that raises (e.g. `raise_*`), or a call to a validate method (e.g. `validate_*!`), when subsequent code follows in the same block:

```ruby
# Correct
raise_unknown_filter_error(key)

result
```

```ruby
# Incorrect
raise_unknown_filter_error(key)
result
```

No blank line is needed when the call is the last line in its block or method.
