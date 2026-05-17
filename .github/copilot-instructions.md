# Copilot Instructions

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
