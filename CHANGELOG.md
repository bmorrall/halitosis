## [Unreleased]

- Leave link properties that evaluate to `nil` out of the rendered link, instead of rendering them as `null`.
- Add `enforce_allow_include!` to resource serializers. When enabled, any requested include path (top-level or nested) without a matching `allow_include` declaration raises `Halitosis::InvalidIncludeParameter`.

## [0.1.0] - 2024-09-30

- Initial release
