# Oaskit

<!-- rdmx :badges
    hexpm         : "oaskit?color=4e2a8e"
    github_action : "lud/oaskit/elixir.yaml?label=CI&branch=main"
    license       : oaskit
    -->
[![hex.pm Version](https://img.shields.io/hexpm/v/oaskit?color=4e2a8e)](https://hex.pm/packages/oaskit)
[![Build Status](https://img.shields.io/github/actions/workflow/status/lud/oaskit/elixir.yaml?label=CI&branch=main)](https://github.com/lud/oaskit/actions/workflows/elixir.yaml?query=branch%3Amain)
[![License](https://img.shields.io/hexpm/l/oaskit.svg)](https://hex.pm/packages/oaskit)
<!-- rdmx /:badges -->

Oaskit is a set of macros and plugs for Elixir/Phoenix applications to
automatically validate incoming HTTP requests based on the [OpenAPI
Specification v3.1](https://spec.openapis.org/oas/v3.1.1.html).

* Request bodies, path and query parameters validation with JSON schemas
  supported by [JSV](https://hex.pm/packages/jsv).
* Heavily inspired by [OpenApiSpex](https://hex.pm/packages/open_api_spex).
* Mix task for JSON file specification generation.


## Documentation

The [Documentation](https://hexdocs.pm/oaskit/) is available on hexdocs,
including a [Quickstart Guide](https://hexdocs.pm/oaskit/quickstart.html) to
dive right in.


## Installation

<!-- rdmx :app_dep vsn:$app_vsn -->
```elixir
def deps do
  [
    {:oaskit, "~> 0.7"},
  ]
end
```
<!-- rdmx /:app_dep -->

You can also import formatter rules in your `.formatter.exs` file:

```elixir
[
  import_deps: [:oaskit]
]
```

## Contributing

Pull requests are welcome, provided they include appropriate tests and
documentation.

## Roadmap

* Serve SwaggerUI or redoc.
* Provide header validation.
* Define JSON schemas for the default error handler responses.