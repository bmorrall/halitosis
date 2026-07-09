## [Unreleased]

- Add `enforce_allow_include!` to resource serializers. When enabled, any requested include path (top-level or nested) without a matching `allow_include` declaration raises `Halitosis::InvalidIncludeParameter`.

## [0.1.0] - 2024-09-30

- Initial release
