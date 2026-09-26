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

Oaskit is an OpenAPI 3.1 library for Elixir and Phoenix: spec generation,
request validation and casting, built on JSON Schema 2020-12.

It provides macros and plugs to automatically validate incoming HTTP requests
against the [OpenAPI Specification
v3.1](https://spec.openapis.org/oas/v3.1.1.html).

* Request bodies, path, query and header parameters validation with JSON Schema
  2020-12, powered by [JSV](https://hex.pm/packages/jsv), a validator that
  passes the official JSON Schema test suite.
* Full OpenAPI 3.1 support: `type: ["string", "null"]` instead of
  `nullable: true`, `oneOf`/`anyOf`/`allOf`, `$ref` and `$defs` behave as the
  JSON Schema specification says.
* Schemas are modules, plain Elixir maps, or JSON files: anything JSV accepts.
* Response validation helpers for your tests.
* Mix task for JSON file specification generation, and a controller to serve
  the spec and a Redoc UI.
* Heavily inspired by [OpenApiSpex](https://hex.pm/packages/open_api_spex),
  which targets OpenAPI 3.0. Oaskit is the choice when you need OpenAPI 3.1.


## Documentation

The full [documentation](https://hexdocs.pm/oaskit/) is available on hexdocs:

* [Quickstart](https://hexdocs.pm/oaskit/quickstart.html)
* [API controllers in the web module](https://hexdocs.pm/oaskit/web-module.html)
* [Using external specs](https://hexdocs.pm/oaskit/external-specs.html)
* [Extensions](https://hexdocs.pm/oaskit/extensions.html)
* [Security](https://hexdocs.pm/oaskit/security.html)
* [Limitations](https://hexdocs.pm/oaskit/limitations.html)


## Installation

<!-- rdmx :app_dep vsn:$app_vsn -->
```elixir
defp deps do
  [
    {:oaskit, "~> 0.16"},
  ]
end
```
<!-- rdmx /:app_dep -->

You can also import formatter rules in your `.formatter.exs` file:

<!-- rdmx :section name:formatter_config format: true -->
```elixir
[
  import_deps: [:oaskit]
]
```
<!-- rdmx /:section -->


## Example

A condensed tour. The [Quickstart
Guide](https://hexdocs.pm/oaskit/quickstart.html) walks through each step in
more detail.

### The spec module

The spec module is the root of your OpenAPI document. Paths are collected from
the Phoenix router.

<!-- rdmx :section name:api_spec_module format: true -->
```elixir
defmodule MyAppWeb.ApiSpec do
  alias Oaskit.Spec.Paths
  alias Oaskit.Spec.Server
  use Oaskit

  @impl true
  def spec do
    %{
      openapi: "3.1.1",
      info: %{title: "My App API", version: "1.0.0"},
      servers: [Server.from_config(:my_app, MyAppWeb.Endpoint)],
      paths: Paths.from_router(MyAppWeb.Router, filter: &String.starts_with?(&1.path, "/api/"))
    }
  end
end
```
<!-- rdmx /:section -->

### Router and controllers

Declare the spec in a router pipeline, and add the validation plug to your
controllers.

<!-- rdmx :section name:router_and_controllers format: true -->
```elixir
# router.ex
pipeline :api do
  plug :accepts, ["json"]
  plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.ApiSpec
end

scope "/api", MyAppWeb do
  pipe_through :api
  get "/users", UserController, :index
  post "/users", UserController, :create
  patch "/users/:id", UserController, :update
end

# my_app_web.ex
def controller do
  quote do
    use Phoenix.Controller, formats: [:json]
    use Oaskit.Controller
    plug Oaskit.Plugs.ValidateRequest
    # ...
  end
end
```
<!-- rdmx /:section -->

### Schemas

Oaskit validates with [JSV](https://hex.pm/packages/jsv), so a schema can be a
module, a plain Elixir map, or a JSON document decoded from a file.

A **schema module** defined with `JSV.defschema/3` is referenced by name, and
valid request bodies are cast to its struct. Properties are required unless
wrapped with `optional/1`, and the struct can be encoded to JSON.

<!-- rdmx :section name:schema_module format: true -->
```elixir
defmodule MyAppWeb.Schemas do
  use JSV.Schema

  defschema User,
    name: non_empty_string(),
    email: email(),
    # OpenAPI 3.1: a type union, no more `nullable: true`
    nickname: optional(%{type: [:string, :null]})
end
```
<!-- rdmx /:section -->

An **inline schema** is plain Elixir data, given directly or with the
`{schema, options}` form.

<!-- rdmx :section name:controller_operations format: true -->
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  alias MyAppWeb.Schemas.User

  # Parameters are validated and cast: `limit` is an integer here
  operation :index,
    parameters: [
      limit: [in: :query, schema: %{type: :integer, minimum: 1, maximum: 100}]
    ],
    responses: [ok: {%{type: :array, items: User}, []}]

  def index(conn, _params) do
    users = MyApp.Users.list(limit: query_param(conn, :limit, 20))
    json(conn, users)
  end

  # Using a schema module
  operation :create,
    request_body: User,
    responses: [created: User]

  def create(conn, _params) do
    %User{} = user = body_params(conn)
    # ...
  end

  # Using an inline schema
  operation :update,
    parameters: [id: [in: :path, schema: %{type: :integer}]],
    request_body:
      {%{
         type: :object,
         properties: %{email: %{type: :string, format: :email}},
         required: [:email],
         additionalProperties: false
       }, required: true},
    responses: [ok: User]

  def update(conn, _params) do
    id = path_param(conn, :id)
    %{"email" => email} = body_params(conn)
    # ...
  end
end
```
<!-- rdmx /:section -->

Invalid requests are rejected with a JSON response describing the errors: `400`
for invalid parameters, `422` for an invalid body and `415` for an unsupported
content type. Errors can be rendered your own way with the `:error_handler`
option of `Oaskit.Plugs.ValidateRequest`.

### Testing responses

`Oaskit.Test.valid_response/3` checks the status, content type and body of a
response against your spec, and returns the decoded body.

<!-- rdmx :section name:test_example format: true -->
```elixir
test "create user", %{conn: conn} do
  conn =
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/api/users", %{name: "Alice", email: "alice@example.com"})

  assert %{"name" => "Alice"} = Oaskit.Test.valid_response(MyAppWeb.ApiSpec, conn, 201)
end
```
<!-- rdmx /:section -->

### Generating and serving the spec

Write the spec to a file, for client generators or CI checks:

<!-- rdmx :section name:openapi_dump format: true -->
```bash
mix openapi.dump MyAppWeb.ApiSpec --pretty -o priv/openapi.json
```
<!-- rdmx /:section -->

Or serve it, with a Redoc UI:

<!-- rdmx :section name:spec_controller format: true -->
```elixir
get "/openapi.json", Oaskit.SpecController, spec: MyAppWeb.ApiSpec
get "/docs", Oaskit.SpecController, redoc: "/openapi.json"
```
<!-- rdmx /:section -->


## Contributing

Pull requests are welcome, provided they include appropriate tests and
documentation.


## Roadmap

* Serve Swagger UI.
* Allow custom formatters for the `openapi.dump` Mix task, to support other
  output formats such as YAML.
