# Changelog

All notable changes to this project will be documented in this file.

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

- Improve handling of shared and operation tags (#69)
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
- Add support to simple header parameters (#37)
- Add precast for array of ref query parameter (#38)

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

- Ensure response body is a binary in Oaskit.Test.valid_response (#23)
- Fixed normalization of %Reference{} structs

## [0.5.1] - 2025-10-10

### 🐛 Bug Fixes

- Don't erase existing private conn data in ValidateRequest (#20)

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

