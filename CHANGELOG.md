# Changelog

All notable changes to this project will be documented in this file.

## [0.15.0] - 2026-09-22

### 🚀 Features

- Support description, deprecated and allowReserved on parameters (#147) (_Stefan Fochler_)

### 🐛 Bug Fixes

- Require timezone offset in the time format per RFC 3339 (_lud_)

### 📚 Documentation

- Added missing docs for public API (_lud_)

### 🧪 Testing

- Updated orval build (_lud_)

### ⚙️ Miscellaneous Tasks

- Limit justfile verbosity on mix.deps (_lud_)

## [0.14.2] - 2026-07-06

### 🐛 Bug Fixes

- Handle new texture 1.2 http structured fields parse errors (_lud_)

## [0.14.1] - 2026-07-05

### 🐛 Bug Fixes

- Removed required openIdConnectUrl parameter for mutualTLS security scheme (_lud_)

### 🧪 Testing

- Cover HTML rendering of header validation errors (_lud_)
- Cover HTML rendering and escaping of body validation errors (_lud_)
- Guard against query-object-key XSS via a plain GET link (_lud_)

### 🛡️ Security

- Prevent XSS in default HTML error handler (_lud_)
- Pin Redoc CDN bundle with subresource integrity (_lud_)

## [0.14.0] - 2026-06-28

### 🚀 Features

- Support object type parameters (_lud_)
- Validate response headers in Oaskit.Test.valid_response/3 (_lud_)

### 📚 Documentation

- Simplify custom web module definition for API controllers (_lud_)

## [0.13.2] - 2026-06-26

### 📚 Documentation

- Encourage users to use custom controller setup in web module (_lud_)
- Show how to use @external_resource for imported specs (_lud_)

## [0.13.1] - 2026-05-29

### 📚 Documentation

- Fix docs for JSV module based schemas now expecting json_schema/0 (#98) (_Ludovic Dem_)

### ⚙️ Miscellaneous Tasks

- Fix compilation warnings for Elixir 1.20 (_lud_)

## [0.13.0] - 2026-05-10

### 🚀 Features

- Upgrade to JSV 0.19 new cast system (_lud_)

## [0.12.0] - 2026-03-19

### 🚀 Features

- [**breaking**] Changed schema titles for all Oaskit errors, possibly impacting client generators (_lud_)

### ⚙️ Miscellaneous Tasks

- Updated license to Apache-2.0 (_lud_)

## [0.11.0] - 2026-01-20

### 🚀 Features

- Pass the :extensions options to the security plug (_lud_)

### 🐛 Bug Fixes

- Added validation constraints for security scheme objects (_lud_)

## [0.10.1] - 2026-01-15

### 🐛 Bug Fixes

- Relax cli_mate dependency version requirement (_lud_)

## [0.10.0] - 2026-01-08

### 🛡️ Security

- [**breaking**] The security plug is now called on all operations (_lud_)

## [0.9.1] - 2025-12-31

### 🐛 Bug Fixes

- Improve handling of shared and operation tags (#69) (_Jaden_)
- Fixed merging of parameters and tag with operation macro (_lud_)

## [0.9.0] - 2025-12-11

### 🚀 Features

- [**breaking**] Renamed unprocessable_entity to unprocessable_content (_lud_)

## [0.8.0] - 2025-11-21

### 🚀 Features

- Added experimental support for operation extensions (_lud_)

### 🐛 Bug Fixes

- Take all existing operation fields from operation macro (_lud_)

## [0.7.0] - 2025-11-13

### 🚀 Features

- Support explode and delimiters in query parameters validator (_lud_)
- Automatically strip '[]' suffix from parameter names in validation (_lud_)
- Add support to simple header parameters (#37) (_Yannis Weishaupt_)
- Add precast for array of ref query parameter (#38) (_Yannis Weishaupt_)

### 🚜 Refactor

- Simplify parameter precast build code (_lud_)
- Return explicit server config fetch errors (_lud_)

### 📚 Documentation

- Document security option on operation macro (_lud_)

### 🧪 Testing

- Instrument Orval to test enforced array brackets (_lud_)

## [0.6.0] - 2025-10-13

### 🚀 Features

- Added operation-level security check using user-defined plugs (_lud_)
- Added support for root level security requirements (_lud_)
- Handling security is now mandatory (_lud_)

### 🐛 Bug Fixes

- Ensure response body is a binary in Oaskit.Test.valid_response (#23) (_Yannis Weishaupt_)
- Fixed normalization of %Reference{} structs (_lud_)

## [0.5.1] - 2025-10-10

### 🐛 Bug Fixes

- Don't erase existing private conn data in ValidateRequest (#20) (_Yannis Weishaupt_)

### 🧪 Testing

- Ensure spec and operation id are preserved in private conn data (_lud_)

## [0.5.0] - 2025-09-16

### 🚀 Features

- [**breaking**] ABNF parser dependency isn't optional anymore (_lud_)

## [0.4.1] - 2025-08-25

### 🚀 Features

- Expose SpecValidator and SpecDumper tools (_lud_)

## [0.4.0] - 2025-08-21

### 🚀 Features

- Provide request and response data abstractions for custom validations (_lud_)

## [0.3.1] - 2025-07-18

### 🚀 Features

- Added the :unprefix option to remove an URL prefix in Paths.from_router/2 (_lud_)

## [0.3.0] - 2025-07-10

### ⚙️ Miscellaneous Tasks

- Upgrade OpenAPI spec schemas for JSV 0.10 (_lud_)

## [0.2.0] - 2025-07-05

### 🚀 Features

- Provide a JSON schema for the default error responses (_lud_)

## [0.1.2] - 2025-06-30

### 🚀 Features

- Provide a controller to serve the specs and Redoc UI (_lud_)

## [0.1.1] - 2025-06-29

### 📚 Documentation

- Fix doc rendering on hexdocs.pm (_lud_)

### ⚙️ Miscellaneous Tasks

- Setup versioning (_lud_)

## [0.1.0] - 2025-06-29

### 🚀 Features

- Initialize from proof of concept (_lud_)

### ⚙️ Miscellaneous Tasks

- Hex package setup (_lud_)

