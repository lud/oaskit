# Using an External Specification

This guide shows how to use Oaskit with existing OpenAPI specification documents
(JSON or YAML files) to validate HTTP requests and responses in your Phoenix
application.

## Overview

While Oaskit can generate OpenAPI specifications from your controllers using the
`operation/2` macro, you may want to work with existing specification documents
instead. This approach is useful when:

* You have an existing OpenAPI specification that you need to implement.
* You prefer to write your API specification first, maybe in cooperation with
  frontend developers or consumers of the API.
* You are generating the specification by other means.

## Spec Module Setup

Create a module that implements the `Oaskit` behavior and returns your OpenAPI
specification.

Then read the spec from the external source and return it from the `spec/0`
callback. It's better to read the external source at compile time if possible,
to avoid unnecessary resource consumption. You can store the spec in an
attribute during compilation.

Below is an example with JSON. Oaskit does not ship with a YAML parsing library,
but you can of course bring your own. As the `c:Oaskit.spec/0` callback must
return data, and not a raw JSON string, you can actually parse that data from any
source.

<!-- rdmx :section name:external_json_spec format: true -->
```elixir
defmodule MyAppWeb.ExternalApiSpec do
  use Oaskit

  @moduledoc """
  OpenAPI specification loaded from an external document.
  """

  # Load from a JSON file
  @api_spec "priv/openapi/my-api.json"
            |> File.read!()
            |> JSON.decode!()

  @impl true
  def spec, do: @api_spec
end
```
<!-- rdmx /:section -->

You can also define the specification directly in Elixir:

<!-- rdmx :section name:manual_spec format: true -->
```elixir
defmodule MyAppWeb.ManualApiSpec do
  use Oaskit

  @api_spec %{
    "openapi" => "3.1.1",
    "info" => %{
      "title" => "My API",
      "version" => "1.0.0"
    },
    "paths" => %{
      "/users" => %{
        "get" => some_operation
      }
    }
  }

  @impl true
  def spec, do: @api_spec
end
```
<!-- rdmx /:section -->

## Router Configuration

At the router level, there is no difference between generated specs and
"external" specs, as Oaskit will build validation from the full normalized spec.
Just use the `Oaskit.Plugs.SpecProvider` plug as for any spec module.

<!-- rdmx :section name:external_router_config format: true -->
```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
    plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.ExternalApiSpec
  end

  scope "/api", MyAppWeb do
    pipe_through :api

    resources "/users", UserController, only: [:index, :create]
  end
end
```
<!-- rdmx /:section -->

## Using Operations in Controllers

Instead of defining operations with the `operation/2` macro, call the
`use_operation/2` macro to attach operations from your specification to action
functions by their `operationId`.

This will instruct the `Oaskit.Plugs.ValidateRequest` plug to use the validations
defined in the spec when that action is called.

<!-- rdmx :section name:use_operation_macro format: true -->
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  use_operation :index, "listUsers"

  def index(conn, _params) do
    # ...
  end

  use_operation :create, "createUser"

  def create(conn, _params) do
    # ...
  end
end
```
<!-- rdmx /:section -->

## Controller Configuration

Ensure your controllers are configured to use Oaskit validation, typically in
your `MyAppWeb` module.

This is the same setup as for the classic usage of the library with the `operation`
macro.

* Use `Oaskit.Controller` to pull the macros in and inject the setup code
* Plug `Oaskit.Plugs.ValidateRequest` to validate everything when a request hits
  the controller

<!-- rdmx :section name:external_controller_config format: true -->
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

## Working with HTTP Methods

If your action function handles multiple operations, specify the method
explicitly:

<!-- rdmx :section name:multiple_operations format: true -->
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  use_operation :generic_handler, "listUsers", method: :get
  use_operation :generic_handler, "createUser", method: :post

  def generic_handler(conn, _params) do
    # ...
  end
end
```
<!-- rdmx /:section -->

## Parameter Handling

> #### Parameter names always create atoms {: .warning}
>
> Query and path parameters defined in OpenAPI specifications always define
> the corresponding atoms, even if that specification is read from a JSON
> file, or defined manually in code with string keys.
>
> For that reason it is ill advised to use specs generated dynamically at
> runtime without validating their content.

The controller helpers to get path params, query params, and body params are
still working, and everything is stored under `conn.private.oaskit`.

<!-- rdmx :section name:external_parameter_handling format: true -->
```elixir
def index(conn, _params) do
  # Path parameters
  slug = path_param(conn, :id)

  # Query parameters
  # defaults to 1
  page = query_param(conn, :page, 1)
  # defaults to nil
  per_page = query_param(conn, :per_page)

  # Request body (for POST/PUT/PATCH requests)
  user_data = body_params(conn)

  # ...
end
```
<!-- rdmx /:section -->

## Test with ExUnit

The `Oaskit.Test.valid_response/3` helper works seamlessly with external
specifications:

<!-- rdmx :section name:external_testing format: true -->
```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase

  # Helper to wrap Oaskit.Test.valid_response/3.
  # Define it in your ConnCase module.
  def valid_response(conn, status) do
    Oaskit.Test.valid_response(MyAppWeb.ExternalApiSpec, conn, status)
  end

  test "list users returns valid response", %{conn: conn} do
    conn = get(conn, ~p"/api/users?page=1&per_page=5")
    assert %{"users" => users} = valid_response(conn, 200)

    # ...
  end

  test "create user with valid data", %{conn: conn} do
    user_params = %{
      name: "John Doe",
      email: "john@example.com"
    }

    conn = post(conn, ~p"/api/users", user_params)

    # Validate against specification and get the JSON data
    assert %{
             "id" => id,
             "name" => "John Doe",
             "email" => "john@example.com"
           } = valid_response(conn, 201)

    # ...
  end

  test "create user with invalid data returns validation errors", %{conn: conn} do
    invalid_params = %{
      name: "",
      email: "invalid-email"
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

## Serving the Specification

You can serve your external specification using the same `Oaskit.SpecController`
as with generated specs:

<!-- rdmx :section name:external_spec_serving format: true -->
```elixir
# In your router
scope "/" do
  pipe_through :api
  get "/openapi.json", Oaskit.SpecController, :show
  get "/docs", Oaskit.SpecController, redoc: "/openapi.json"
end
```
<!-- rdmx /:section -->

But remember that if your external spec is a static JSON file, you can just
serve that file with `Plug.Static` or Nginx, Apache, etc.


## Mixing Approaches

Finally, you can combine both approaches in the same application. This is useful
when you want to implement a predefined API but also want to add new routes.

<!-- rdmx :section name:hybrid_spec format: true -->
```elixir
defmodule MyAppWeb.HybridApiSpec do
  alias Oaskit.Spec.Paths
  use Oaskit

  @base_spec "priv/openapi/core-api.json"
             |> File.read!()
             |> Jason.decode!()

  @impl true
  def spec do
    Map.update!(@base_spec, "paths", fn existing_paths ->
      Map.merge(existing_paths, admin_paths())
    end)
  end

  defp admin_paths do
    Paths.from_router(
      MyAppWeb.Router,
      filter: &String.starts_with?(&1.path, "/admin")
    )
  end
end
```
<!-- rdmx /:section -->

You can also merge different routers, paths from multiple files, _etc._ This will
merge together specs defined with atom keys and structs with specs defined only
with strings. It's not a problem since Oaskit will normalize it before building
the validation.

The only concern is to make sure that you do not override paths unknowingly if
for some reason one of the specs uses atoms for path keys.