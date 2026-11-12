## [Unreleased]

- **Breaking:** JSON:API-style sideloading of included relationships into `_included` is now the default. Removed the `collect_includes!` class method and the `config.collect_includes` option.
- Add `legacy_nesting!` for clients that still read nested relationships. Included relationships are also rendered nested inline, each with a `_type` key added next to its identifier, in addition to being sideloaded into `_included`. Sideloaded records are unaffected: their relationships are always typed stubs.
- When the same resource is reached by several include paths (e.g. `a.b.c,a.d.b.e`), its sideloaded payload now includes the relationships requested by every path, not only the first.
- Leave link properties that evaluate to `nil` out of the rendered link, instead of rendering them as `null`.
- Add `enforce_allow_include!` to resource serializers. When enabled, any requested include path (top-level or nested) without a matching `allow_include` declaration raises `Halitosis::InvalidIncludeParameter`.

## [0.1.0] - 2024-09-30

- Initial release
