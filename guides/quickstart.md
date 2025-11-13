# Oaskit Quickstart Guide

Welcome to Oaskit! This guide will walk you through setting up and using Oaskit to validate HTTP requests in your Phoenix application based on OpenAPI 3.1 specifications.


## Installation

First, add Oaskit to your dependencies in `mix.exs`:

<!-- rdmx :app_dep vsn:$app_vsn -->
```elixir
def deps do
  [
    {:oaskit, "~> 0.7"},
  ]
end
```
<!-- rdmx /:app_dep -->

You will most probably use macros from this library, import formatter rules in
your `.formatter.exs` file:

<!-- rdmx :section name:formatter_config format: true -->
```elixir
# .formatter.exs
[
  import_deps: [:oaskit]
]
```
<!-- rdmx /:section -->


## Creating an API Specification Module

Create a module that defines your OpenAPI specification using the `Oaskit`
module. This module will serve as the central definition of your API:

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
      info: %{
        title: "My App API",
        version: "1.0.0",
        description: "Main HTTP API for My App"
      },
      servers: [Server.from_config(:my_app, MyAppWeb.Endpoint)],
      paths: Paths.from_router(MyAppWeb.Router, filter: &String.starts_with?(&1.path, "/api/"))
    }
  end
end
```
<!-- rdmx /:section -->

The `Oaskit.Spec.Paths.from_router/2` function automatically extracts API
paths from your Phoenix router, focusing only on controller actions that have
operations defined. The optional `:filter` function lets you limit which routes
are included in your specification.


## Setting Up Router Pipelines

Configure your Phoenix router to use Oaskit validation with your API spec
module by setting up a pipeline with the `Oaskit.Plugs.SpecProvider` plug:

<!-- rdmx :section name:router_pipeline format: true -->
```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router

  # Define a pipeline for API routes with Oaskit validation
  pipeline :api do
    plug :accepts, ["json"]
    plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.ApiSpec
  end

  # Apply the pipeline to your API routes
  scope "/api", MyAppWeb do
    pipe_through :api

    resources "/users", UserController, only: [:index, :show, :create]
    resources "/posts", PostController, only: [:index, :show, :create, :update]
  end
end
```
<!-- rdmx /:section -->

The `Oaskit.Plugs.SpecProvider` plug is required as a controller action and
its defined OpenAPI operation can be referenced in multiple specifications.


## Configuring Controllers

Set up your controllers to use Oaskit validation. You can do this globally in
your `MyAppWeb` module:

<!-- rdmx :section name:controller_config format: true -->
```elixir
defmodule MyAppWeb do
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: MyAppWeb.Layouts]

      # Add Oaskit controller macros
      use Oaskit.Controller

      # Add the validation plug
      plug Oaskit.Plugs.ValidateRequest

      import Plug.Conn
      use Gettext, backend: MyAppWeb.Gettext

      unquote(verified_routes())
    end
  end

  # ...
end
```
<!-- rdmx /:section -->

This setup ensures all controllers using `use MyAppWeb, :controller` will have
Oaskit validation enabled. See the documentation of
`Oaskit.Plugs.ValidateRequest` to configure the plug globally for only a
subset of your controllers.


## Defining Operations in Controllers

Now you can define operations in your controllers using the
`Oaskit.Controller.operation/2` macro.

To import the macros, use your `:controller` helper as usual since you've added
`use Oaskit.Controller` in the previous step.

<!-- rdmx :section name:controller_use format: true -->
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  # ...
end
```
<!-- rdmx /:section -->

The operation macro takes the function name and the operation specs as
arguments.

In this example we use syntax shortcuts to refer directly to schemas, but the
operation macro lets you define responses or requests with multiple content
types, custom descriptions and many other options. Make sure to read the docs!

<!-- rdmx :section name:operation_definition format: true -->
```elixir
operation :create,
  summary: "Create a new user",
  request_body: {
    %{
      type: :object,
      properties: %{
        name: %{type: :string, minLength: 1},
        email: %{type: :string, format: :email},
        age: %{type: :integer, minimum: 18}
      },
      required: [:name, :email]
    },
    description: "The user payload"
  },
  parameters: [
    source: [in: :query, schema: %{type: :string}, required: false]
  ],
  responses: [
    created: UserSchema,
    unprocessable_entity: ErrorSchema
  ]

def create(conn, _params) do
  # The `_params` variable from phoenix is not changed by the validation plug.
  #
  # Validated and cast data is stored in `conn.private.oaskit`.
  #
  # You may explore what's in there (or read the docs), or you may use the
  # various helpers from the `Oaskit.Controller` module:
  user_data = body_params(conn)
  source = query_param(conn, :source)

  case create_user(user_data, source) do
    # ...
  end
end
```
<!-- rdmx /:section -->


### Defining JSON Schemas

There are two ways to provide schemas in the various macros, either inline or
using modules.

#### Inline schemas

Inline schemas are maps (with atoms or binary keys and values) or booleans.

<!-- rdmx :section name:inline_schemas format: true -->
```elixir
@user_schema %{
  type: :object,
  title: "User",
  properties: %{
    name: %{type: :string, minLength: 1},
    email: %{type: :string, format: :email},
    age: %{type: :integer, minimum: 0}
  },
  required: [:name, :email]
}

operation :create,
  request_body: {@user_schema, [required: true]},
  responses: [ok: {@user_schema, []}]
```
<!-- rdmx /:section -->

While they are practical, such maps are duplicated in the compiled module as
well as in the OpenAPI specification document.


#### Module-based schemas

A module-based schema is any module that exports a `schema/0` function returning
a valid JSON schema.

Oaskit uses [JSV](https://hex.pm/packages/jsv). Module-based schemas defined
with `JSV.defschema/1` are automatically cast to structs when validation
succeeds, making them convenient to work with, notably thanks to the new Elixir
types compiler!

Make sure to check the [JSV
documentation](https://hexdocs.pm/jsv/defining-schemas.html) for additional
features.

<!-- rdmx :section name:module_schemas format: true -->
```elixir
defmodule MyAppWeb.Schemas.UserSchema do
  use JSV.Schema

  defschema %{
    type: :object,
    title: "User",
    properties: %{
      id: %{type: :integer},
      name: %{type: :string, minLength: 1},
      email: %{type: :string, format: :email},
      age: %{type: :integer, minimum: 18}
    },
    required: [:id, :name, :email]
  }
end

# Use the module directly in operations in place of a schema
operation :show,
  responses: [ok: MyAppWeb.Schemas.UserSchema]
```
<!-- rdmx /:section -->

Such schemas are collected into the `#/components/schemas` section of the
OpenAPI specification, which makes that document shorter, easier to navigate,
and limits the memory usage at runtime.


### Shared tags and parameters

Oaskit provides the `Oaskit.Controller.tags/1` and
`Oaskit.Controller.parameter/2` macros for shared elements between
operations.

Those macros only apply to operations defined _after_ them.

<!-- rdmx :section name:shared_elements format: true -->
```elixir
# Add tags to group operations in documentation
tags ["users", "public"]

# Define parameters once for multiple operations
parameter :page, in: :query, schema: %{type: :integer}
parameter :per_page, in: :query, schema: %{type: :integer}
```
<!-- rdmx /:section -->


## Testing with Oaskit.Test

The `valid_response/3` helper validates that the response matches your OpenAPI
specification, including status code, content type, and response body schema. It
returns the parsed response data for further assertions.

<!-- rdmx :section name:test_example format: true -->
```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase

  # Helper to wrap Oaskit.Test.valid_response/3
  # Feel free to add it directly into your ConnCase module!
  defp valid_response(conn, status) do
    Oaskit.Test.valid_response(MyAppWeb.ApiSpec, conn, status)
  end

  test "create user with valid data", %{conn: conn} do
    user_params = %{
      name: "John Doe",
      email: "john@example.com",
      age: 25
    }

    conn = post(conn, ~p"/api/users", user_params)

    # Validate the response against your OpenAPI specification. It returns
    # decoded data for JSON content-types.
    assert %{
             "name" => "John Doe",
             "email" => "john@example.com",
             "age" => 25
           } =
             valid_response(conn, 201)
  end

  test "create user with invalid data returns validation errors", %{conn: conn} do
    invalid_params = %{
      name: "",
      email: "invalid-email",
      age: 15
    }

    conn = post(conn, ~p"/api/users", invalid_params)

    # You can use `valid_response` if you define a response schema for the
    # errors. See `Oaskit.ErrorHandler.Default.error_response_schema/0`.
    #
    # valid_response(conn, 422)

    # If you do not declare all possible responses, using the good old
    # `Phoenix.ConnTest.json_response/2` works fine!
    assert json_response(conn, 422)
  end
end
```
<!-- rdmx /:section -->


## Generating OpenAPI Documentation

Once you have your operations defined, you can generate an OpenAPI specification
file using the Mix task:

<!-- rdmx :section name:openapi_dump format: true -->
```bash
mix openapi.dump MyAppWeb.ApiSpec --pretty -o priv/openapi.json
```
<!-- rdmx /:section -->

This generates a complete OpenAPI 3.1 specification file that can be used with
various tools like client generators for TypeScript or Elixir.


## Serving OpenAPI Specifications

You can serve your OpenAPI specification dynamically using the
`Oaskit.SpecController`. This controller serves your specification as JSON at an
HTTP endpoint.

Add the controller to your router:

<!-- rdmx :section name:spec_controller format: true -->
```elixir
get "/openapi.json", Oaskit.SpecController, spec: MyAppWeb.ApiSpec
```
<!-- rdmx /:section -->

This will serve your OpenAPI specification at `/openapi.json`. Pass `?pretty=1`
to get pretty printed JSON.

You can also use that controller to serve Redoc UI. Pass the full URL path to
the json route you just defined:

<!-- rdmx :section name:redoc_controller format: true -->
```elixir
get "/docs", Oaskit.SpecController, redoc: "/openapi.json"
```
<!-- rdmx /:section -->

Redoc allows you to browse your API endpoints, view request/response schemas,
and see examples, but note that it is read-only and doesn't allow testing the
API directly.

## Ask for help!

If anything is unclear, or if you would like to see more features, plase fill an
issue in the [Github repository](https://github.com/lud/oaskit).

Happy coding!