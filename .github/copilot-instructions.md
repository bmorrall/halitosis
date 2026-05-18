# Copilot Instructions

## Fields

Fields must only be created at DSL time (class definition), never at instance or render time.
Use `fields.add(...)` inside class-level DSL methods only (e.g. `paginate_with`, `paginate_links`).
Creating fields dynamically during rendering is not permitted.

## Serializer immutability

Serializer instances are immutable after `initialize`. **Never add instance variables to the serializer** — not during rendering, not after rendering, not ever. This includes `@collection`, `@query_params`, `@last_context`, or any other state.

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

All mutable render-time state belongs exclusively on the `Context` object (or `CollectionContext` for collection serializers), not on the serializer instance.

## Raise calls

Always add a blank line after a `raise`, a call to a method that raises (e.g. `raise_*`), a call to a validate method (e.g. `validate_*!`), or an inline conditional (e.g. `return x if condition`, `value = expr unless condition`), when subsequent code follows in the same block:

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

## Calling procedures on the serializer instance

Never call `instance_exec` directly on a serializer instance. Always use `context.call_instance` or `context.call_instance_with` instead — these are the canonical dispatch points and keep all invocation logic in one place.

```ruby
# Correct
context.call_instance_with(collection, procedure)

# Incorrect
instance.instance_exec(collection, &procedure)
```

The only permitted use of `instance_exec` is inside `Context#call_instance` and `Context#call_instance_with` themselves.
