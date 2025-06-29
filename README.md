# OpenApify

<!-- rdmx :badges
    hexpm         : "open_apify?color=4e2a8e"
    github_action : "lud/open_apify/elixir.yaml?label=CI&branch=main"
    license       : open_apify
    -->
[![hex.pm Version](https://img.shields.io/hexpm/v/open_apify?color=4e2a8e)](https://hex.pm/packages/open_apify)
[![Build Status](https://img.shields.io/github/actions/workflow/status/lud/open_apify/elixir.yaml?label=CI&branch=main)](https://github.com/lud/open_apify/actions/workflows/elixir.yaml?query=branch%3Amain)
[![License](https://img.shields.io/hexpm/l/open_apify.svg)](https://hex.pm/packages/open_apify)
<!-- rdmx /:badges -->

OpenApify is a set of macros and plugs for Elixir/Phoenix applications to
automatically validate incoming HTTP requests based on the [OpenAPI Specification v3.1](https://spec.openapis.org/oas/v3.1.1.html).

* Request bodies, path and query parameters validation with JSON schemas
  supported by [JSV](https://hex.pm/packages/jsv).
* Heavily inspired by [OpenApiSpex](https://hex.pm/packages/open_api_spex).
* Mix task for JSON file specification generation.


## Documentation

[API documentation is available on hexdocs.pm](https://hexdocs.pm/open_apify/).


## Installation

<!-- rdmx :app_dep vsn:$app_vsn -->
```elixir
def deps do
  [
    {:open_apify, "~> 0.1"},
  ]
end
```
<!-- rdmx /:app_dep -->

You can also import formatter rules in your `.formatter.exs` file:

```elixir
[
  import_deps: [:open_apify]
]
```

## Contributing

Pull requests are welcome, provided they include appropriate tests and documentation.

## Roadmap

* Automatically serve the specification using SwaggerUI or redoc. Or at least
  the JSON document.
* Provide header validation.
* Define JSON schemas for the default error handler responses.