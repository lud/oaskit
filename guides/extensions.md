# Extensions

Extensions in Oaskit are a way to attach custom data to your operations. They are not "plugins" that modify the behavior of the library, but rather a mechanism to carry arbitrary key-value pairs alongside your operation definitions.

This feature is particularly useful when you need to:
- Add custom metadata to your OpenAPI specification (using standard `x-` vendor extensions).
- Pass internal configuration or flags to your controllers that are specific to an operation but don't belong in the request parameters.

## Adding Extensions

You can add extensions directly in the `operation` macro in your controller. Any key that is not a standard OpenAPI field (like `summary`, `description`, `parameters`, etc.) is treated as an extension.

```elixir
defmodule MyAppWeb.UserController do
  use Oaskit.Controller

  operation :create,
    summary: "Create a user",
    # Standard OpenAPI fields...

    # Public extension (will appear in the generated spec)
    "x-rate-limit": 100,

    # Private extension (internal use only)
    required_permission: :admin_write

  def create(conn, params) do
    # ...
  end
end
```

## Public vs. Private Extensions

Oaskit distinguishes between two types of extensions based on their key name:

### Public Extensions (`x-` prefix)
If an extension key starts with `x-`, it is treated as a standard OpenAPI [Specification Extension](https://spec.openapis.org/oas/v3.1.0#specification-extensions).
- **Exported**: These extensions **will be included** in the generated OpenAPI JSON file (e.g., when running `mix openapi.dump`).
- **Usage**: Use these for tools that consume your OpenAPI spec (e.g., documentation generators, code generators, API gateways).

### Private Extensions (no `x-` prefix)
If an extension key does **not** start with `x-`, it is considered private.
- **Internal**: These extensions **will NOT be included** in the generated OpenAPI JSON file.
- **Usage**: Use these to pass metadata to your application logic without exposing implementation details in your public API documentation.

## Accessing Extensions in Controllers

Both public and private extensions are available to you at runtime within your controller actions. They are stored in the `conn.private.oaskit.extensions` map.

<!-- rdmx :section name:controller_example format: true -->
```elixir
def create(conn, _params) do
  extensions = conn.private.oaskit.extensions

  # Accessing the extensions defined above
  rate_limit = extensions."x-rate-limit"
  permission = extensions.required_permission

  # Use the extensions in your logic
  if current_user_can?(permission) do
    # ...
  end
end
```
<!-- rdmx /:section -->

## What to Expect

- **Data Types**: You can pass almost any Elixir term as a value for a private extension (structs, tuples, etc.). However, for public extensions (`x-`), the values should be JSON-encodable since they need to be written to the OpenAPI spec file.
- **Normalization**: Oaskit attempts to preserve the original values you passed in the `operation` macro so you can use them directly in your controller.
