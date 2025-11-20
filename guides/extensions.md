# Extensions

Extensions in Oaskit are a way to attach custom data to your operations. They
are not "plugins" that modify the behavior of the library, but rather a
mechanism to carry arbitrary key-value pairs alongside your operation
definitions.

This feature is useful when you need to:
- Add custom metadata to your OpenAPI specification (using standard `x-` vendor
  extensions).
- Pass internal configuration or flags to your controllers that are specific to
  an operation but don't belong in the request parameters.

## Adding Extensions

You can add extensions directly in the `operation` macro in your controller. Any
key that is not a standard OpenAPI field (like `summary`, `description`,
`parameters`, etc.) is treated as an extension.

<!-- rdmx :section name:operation_example format: true -->
```elixir
defmodule MyAppWeb.UserController do
  use Oaskit.Controller

  operation :create,
    # Standard OpenAPI fields...
    summary: "Create a user",

    # Public extension (will appear in the generated spec)
    "x-rate-limit": 100,

    # Private extension (internal use only)
    admin_rate_limit: 1000

  def create(conn, params) do
    # ...
  end
end
```
<!-- rdmx /:section -->


## Accessing Extensions in Controllers and Plugs

Both public and private extensions are available to you at runtime within your
controller actions. They are stored in the `conn.private.oaskit.extensions` map.

This is also acessible from your custom plugs that are defined after
`Oaskit.Plugs.ValidateRequest` in the plug pipeline. Operations are matched
after Phoenix selects a route, so those plugs are generally defined in the
controller body from `use MyAppWeb, :controller`.

<!-- rdmx :section name:controller_example format: true -->
```elixir
def create(conn, _params) do
  extensions = conn.private.oaskit.extensions

  # Accessing the extensions defined above
  rate_limit =
    if admin?(conn),
      do: extensions.admin_rate_limit,
      else: extensions."x-rate-limit"

  # rest of your controller implementation
end
```
<!-- rdmx /:section -->


## Valid Extensions

- **Data Types**: You can pass any Elixir term that is JSON encodable as an
  extension value. However, for public extensions (`x-`), the values should be
  JSON-encodable since they need to be written to the OpenAPI spec file.

- **Structs** must implement the `JSV.Normalizer.Normalize` protocol. Just using
  `Map.from_struct/1` is generally enough. This is because full JSON Schema
  support requires that schemas can `$ref` to anywhere in the document, so the
  whole spec must be normalizable as a JSON schema.

- **Tuples** are not supported for the same reason. Unfortunately, this means
  that keywords are not supported either.

- **Normalization**: Oaskit attempts to preserve the original values you passed
  in the `operation` macro so you can use them directly in your controller.


## Public vs. Private Extensions

Oaskit distinguishes between two types of extensions based on the `x-` prefix in
their name.

### Public Extensions
If an extension key starts with `x-`, it is treated as a standard OpenAPI
[Specification Extension](https://spec.openapis.org/oas/v3.1.0#specification-extensions).

These extensions will be included in the generated OpenAPI JSON file when
running `mix openapi.dump`. Use these for tools that consume your OpenAPI spec
(e.g., documentation generators, code generators, API gateways).

### Private Extensions
If an extension key does **not** start with `x-`, it is considered private.

These extensions will not be included in the generated OpenAPI JSON file. Use
these to pass metadata to your application logic without exposing implementation
details in your public API documentation.


## Custom Serialization

Under the hood, Oaskit uses two callbacks in your spec module to handle
extensions: `c:Oaskit.dump_extension/1` and `c:Oaskit.load_extension/1`.

- `dump_extension/1`: Serializes the extension for the OpenAPI spec (or
  normalization).
- `load_extension/1`: Deserializes the extension for use in the controller.

By default, Oaskit implements these to preserve your original Elixir terms using
an internal wrapper.

If you need to customize how extensions are serialized (e.g., to transform a
struct into a specific JSON format for `x-` extensions), you can override these
callbacks.

> #### You should not override only one callbeck {: .warning}
>
> It is recommended to override **both** callbacks if you override one. The
> default implementation relies on internal mechanisms to preserve values. If
> you only override one, you might break this preservation or get unexpected
> results.

<!-- rdmx :section name:serde_example format: true -->
```elixir
defmodule MyAppWeb.OpenAPISpec do
  use Oaskit

  @impl true
  def dump_extension({"x-complex-data", value}) do
    # Transform complex data to JSON for the spec
    {"x-complex-data", MyApp.Serializer.to_json(value)}
  end

  def dump_extension(pair), do: super(pair)

  @impl true
  def load_extension({"x-complex-data", json_value}) do
    # Transform back to struct for the controller
    {"x-complex-data", MyApp.Serializer.from_json(json_value)}
  end

  def load_extension(pair), do: super(pair)
end
```
<!-- rdmx /:section -->
