# Changelog

All notable changes to this project will be documented in this file.

## [0.18.0] - 2026-11-09

### 🚀 Features

- Support time-local and date-time-local schema formats (#164)
- Support serving specs with new Redoc 3 UI

### 🛡️ Security

- Updated Redoc 3 to 3.1.0

## [0.17.1] - 2026-10-08

### 🐛 Bug Fixes

- Precast parameters whose schema reference is not resolved yet (#161) – by Stefan Fochler

## [0.17.0] - 2026-10-04

This release brings a migration path for OpenApiSpex users.

Oaskit now provides an agent skill that migrates a Phoenix application from
OpenApiSpex to Oaskit. Scripts rewrite the schemas, controllers and tests, and
the agent handles the remaining cases. See the
[Migrating from OpenApiSpex](https://hexdocs.pm/oaskit/migrate-from-openapispex.html)
guide to install it and choose what your API clients keep.

Oaskit also supports more of what OpenApiSpex applications rely on:

- JSON request bodies that are not objects, such as arrays, are validated.
- Parameters whose schema type is a union, such as `[:integer, :null]`, are
  cast.
- `Oaskit.warmup_spec_cache/2` and `Oaskit.SpecCacheWarmup` build the spec
  at boot. Concurrent first requests now wait for a single build.

JSV 0.26 adds context data to normalized errors, so error handlers can render
the former OpenApiSpex error format without parsing messages. Oaskit now
requires JSV 0.26.

Breaking: parameters with a type union including `string` no longer pass
numeric or boolean strings unchanged. With `[:integer, :string]`, `"007"` is
cast to `7`.

### 🚀 Features

- Serialize spec builds and add Oaskit.warmup_spec_cache/2
- [**breaking**] Cast parameter values for type unions

### 🐛 Bug Fixes

- Validate non-object JSON request bodies wrapped by Plug

### 📚 Documentation

- Provide a migration skill for OpenAPI 3.0 users
- Documentation changes around new JSV error ctx values

## [0.16.1] - 2026-09-28

### 🐛 Bug Fixes

- Fix transforming single example into examples map
- Correctly take default request/response descriptions from schema modules as documented
- Keep description on request bodies
- Raise explicit error for invalid request body definitions
- Accept maps as parameter definitions

### 🚜 Refactor

- Share media type content casting between request bodies and responses

### 📚 Documentation

- Fix operation/2 docs and README inline schema wording (#153)
- Set JSON content type in guide tests, mention HTML errors in README

### ⚙️ Miscellaneous Tasks

- Various typo fixes

## [0.16.0] - 2026-09-25

### 🚀 Features

- [**breaking**] Drop intermediary JSON schema errors from JSON error responses

## [0.15.0] - 2026-09-22

### 🚀 Features

- Support description, deprecated and allowReserved on parameters (#147) – by Stefan Fochler

### 🐛 Bug Fixes

- Require timezone offset in the time format per RFC 3339

### 📚 Documentation

- Added missing docs for public API

### 🧪 Testing

- Updated orval build

### ⚙️ Miscellaneous Tasks

- Limit justfile verbosity on mix.deps

## [0.14.2] - 2026-07-06

### 🐛 Bug Fixes

- Handle new texture 1.2 http structured fields parse errors

## [0.14.1] - 2026-07-05

### 🐛 Bug Fixes

- Removed required openIdConnectUrl parameter for mutualTLS security scheme

### 🧪 Testing

- Cover HTML rendering of header validation errors
- Cover HTML rendering and escaping of body validation errors
- Guard against query-object-key XSS via a plain GET link

### 🛡️ Security

- Prevent XSS in default HTML error handler
- Pin Redoc CDN bundle with subresource integrity

## [0.14.0] - 2026-06-28

### 🚀 Features

- Support object type parameters
- Validate response headers in Oaskit.Test.valid_response/3

### 📚 Documentation

- Simplify custom web module definition for API controllers

## [0.13.2] - 2026-06-26

### 📚 Documentation

- Encourage users to use custom controller setup in web module
- Show how to use @external_resource for imported specs

## [0.13.1] - 2026-05-29

### 📚 Documentation

- Fix docs for JSV module based schemas now expecting json_schema/0 (#98)

### ⚙️ Miscellaneous Tasks

- Fix compilation warnings for Elixir 1.20

## [0.13.0] - 2026-05-10

### 🚀 Features

- Upgrade to JSV 0.19 new cast system

## [0.12.0] - 2026-03-19

### 🚀 Features

- [**breaking**] Changed schema titles for all Oaskit errors, possibly impacting client generators

### ⚙️ Miscellaneous Tasks

- Updated license to Apache-2.0

## [0.11.0] - 2026-01-20

### 🚀 Features

- Pass the :extensions options to the security plug

### 🐛 Bug Fixes

- Added validation constraints for security scheme objects

## [0.10.1] - 2026-01-15

### 🐛 Bug Fixes

- Relax cli_mate dependency version requirement

## [0.10.0] - 2026-01-08

### 🛡️ Security

- [**breaking**] The security plug is now called on all operations

## [0.9.1] - 2025-12-31

### 🐛 Bug Fixes

- Improve handling of shared and operation tags (#69) – by Jaden
- Fixed merging of parameters and tag with operation macro

## [0.9.0] - 2025-12-11

### 🚀 Features

- [**breaking**] Renamed unprocessable_entity to unprocessable_content

## [0.8.0] - 2025-11-21

### 🚀 Features

- Added experimental support for operation extensions

### 🐛 Bug Fixes

- Take all existing operation fields from operation macro

## [0.7.0] - 2025-11-13

### 🚀 Features

- Support explode and delimiters in query parameters validator
- Automatically strip '[]' suffix from parameter names in validation
- Add support to simple header parameters (#37) – by Yannis Weishaupt
- Add precast for array of ref query parameter (#38) – by Yannis Weishaupt

### 🚜 Refactor

- Simplify parameter precast build code
- Return explicit server config fetch errors

### 📚 Documentation

- Document security option on operation macro

### 🧪 Testing

- Instrument Orval to test enforced array brackets

## [0.6.0] - 2025-10-13

### 🚀 Features

- Added operation-level security check using user-defined plugs
- Added support for root level security requirements
- Handling security is now mandatory

### 🐛 Bug Fixes

- Ensure response body is a binary in Oaskit.Test.valid_response (#23) – by Yannis Weishaupt
- Fixed normalization of %Reference{} structs

## [0.5.1] - 2025-10-10

### 🐛 Bug Fixes

- Don't erase existing private conn data in ValidateRequest (#20) – by Yannis Weishaupt

### 🧪 Testing

- Ensure spec and operation id are preserved in private conn data

## [0.5.0] - 2025-09-16

### 🚀 Features

- [**breaking**] ABNF parser dependency isn't optional anymore

## [0.4.1] - 2025-08-25

### 🚀 Features

- Expose SpecValidator and SpecDumper tools

## [0.4.0] - 2025-08-21

### 🚀 Features

- Provide request and response data abstractions for custom validations

## [0.3.1] - 2025-07-18

### 🚀 Features

- Added the :unprefix option to remove an URL prefix in Paths.from_router/2

## [0.3.0] - 2025-07-10

### ⚙️ Miscellaneous Tasks

- Upgrade OpenAPI spec schemas for JSV 0.10

## [0.2.0] - 2025-07-05

### 🚀 Features

- Provide a JSON schema for the default error responses

## [0.1.2] - 2025-06-30

### 🚀 Features

- Provide a controller to serve the specs and Redoc UI

## [0.1.1] - 2025-06-29

### 📚 Documentation

- Fix doc rendering on hexdocs.pm

### ⚙️ Miscellaneous Tasks

- Setup versioning

## [0.1.0] - 2025-06-29

### 🚀 Features

- Initialize from proof of concept

### ⚙️ Miscellaneous Tasks

- Hex package setup

