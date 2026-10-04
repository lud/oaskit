# Spec modules, router, mix tasks

Names (spec module, spec provider plug, OpenAPI document) are defined in
`SKILL.md`, "Names used in this skill". `rewrite_lib.exs` does not touch spec
modules or routers. Migrate them by hand.

## Spec module

Before:

```elixir
defmodule MyAppWeb.ApiSpec do
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [Server.from_endpoint(MyAppWeb.Endpoint)],
      info: %Info{title: "My API", version: "1.0"},
      paths: Paths.from_router(MyAppWeb.Router),
      components: %Components{
        securitySchemes: %{"bearerAuth" => %SecurityScheme{type: "http", scheme: "bearer"}}
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
```

After:

```elixir
defmodule MyAppWeb.ApiSpec do
  use Oaskit

  alias Oaskit.Spec.{Paths, Server}

  @impl true
  def spec do
    %{
      openapi: "3.1.1",
      servers: [Server.from_config(:my_app, MyAppWeb.Endpoint)],
      info: %{title: "My API", version: "1.0"},
      paths: Paths.from_router(MyAppWeb.Router, filter: &String.starts_with?(&1.path, "/api/")),
      components: %{
        securitySchemes: %{"bearerAuth" => %{type: "http", scheme: "bearer"}}
      }
    }
  end
end
```

- `use Oaskit` replaces `@behaviour OpenApiSpex.OpenApi` and also generates a
  cache for the built document.
- The document is a plain map. The `openapi` version key is required.
  `%Info{}`, `%Components{}`, `%SecurityScheme{}` become maps.
- No `OpenApiSpex.resolve_schema_modules/1`: Oaskit collects JSV schema
  modules into `components.schemas` itself.
- `Oaskit.Spec.Paths.from_router/2` takes the same router as
  `OpenApiSpex.Paths.from_router/1`. Use its `:filter` option when non-API
  routes reuse API actions (see `controllers.md`, "One controller action,
  several routes"). The filter is only called for routes whose action has an
  operation.
- **`OpenApiSpex.Server.from_endpoint/1` → `Oaskit.Spec.Server.from_config/2`.**
  OpenApiSpex read the URL from the running endpoint. Oaskit reads the
  endpoint configuration (`config :my_app, MyAppWeb.Endpoint, url: [...]`),
  so `mix openapi.dump` works without starting the app. The `:url` config
  needs a `host`. Missing `scheme`/`port`/`path` default to
  `"https"`/`443`/`"/"`, so a dev config like `url: [host: "localhost"]`
  gives `https://localhost/` where OpenApiSpex gave
  `http://localhost:4000`. Even with every part configured, the URL ends
  with `/` (the `path` default), and `MyAppWeb.Endpoint.url/0` (used by
  OpenApiSpex) did not: `https://api.example.com/` instead of
  `https://api.example.com`. Clients that concatenate the server URL and
  the paths get `//`. Strip it
  (`Map.update!(Server.from_config(:my_app, MyAppWeb.Endpoint), :url, &String.trim_trailing(&1, "/"))`
  or similar), or write `servers: [%{url: "..."}]` by hand.
- Several spec modules (public API, internal API…) work the same way, one
  spec provider plug per pipeline.

## Building the spec at boot

Oaskit builds the operations and JSV roots of a spec module on the first
validated request, then caches them. Build them at boot instead, so that
duplicate operationIds and unknown formats stop the app from starting. Call
`Oaskit.warmup_spec_cache/2` for each spec module at the top of the `start/2`
callback of the application:

```elixir
def start(_type, _args) do
  :ok = Oaskit.warmup_spec_cache(MyAppWeb.ApiSpec)

  children = [
    # ...
  ]

  # ...
end
```

`Server.from_config/2` and `Paths.from_router/2` read the configuration and
the compiled router, so this works before the supervisor starts. When `spec/0`
calls a process of the application (a repo, a GenServer), add
`{Oaskit.SpecCacheWarmup, spec: MyAppWeb.ApiSpec}` to the children instead,
after that process and before the endpoint.

## Router

| OpenApiSpex | Oaskit |
|---|---|
| `plug OpenApiSpex.Plug.PutApiSpec, module: MyAppWeb.ApiSpec` | `plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.ApiSpec` |
| `get "/openapi", OpenApiSpex.Plug.RenderSpec, []` | `get "/openapi", Oaskit.SpecController, :show` (serves the OpenAPI document of the spec module set by the pipeline's spec provider plug), or `get "/openapi", Oaskit.SpecController, spec: MyAppWeb.ApiSpec` |
| `get "/swaggerui", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"` | `get "/docs", Oaskit.SpecController, redoc: "/api/openapi"` (Redoc, read-only. Oaskit has no Swagger UI.) |

`Oaskit.SpecController` serves pretty JSON with `?pretty=1`. Tests that
request the Swagger UI route must change with it.

## Mix tasks and aliases

| OpenApiSpex | Oaskit |
|---|---|
| `mix openapi.spec.json --spec MyAppWeb.ApiSpec --start-app=true --pretty=true doc/openapi.json` | `mix openapi.dump MyAppWeb.ApiSpec --pretty -o doc/openapi.json` |
| `mix openapi.spec.yaml ...` | no YAML output. Convert the JSON with an external tool if needed. |

- `mix openapi.dump` only loads the app config (no app start, no
  `--start-app` option), and validates the document against the OpenAPI 3.1
  meta-schema (warnings printed). It does not build the operations, so it
  does not detect duplicate operationIds or unknown formats (see the phase 7
  gate in `SKILL.md`).
- `--pretty` is the default.
- OpenApiSpex's `--no-start-app` and `--vendor-extensions=false` (or
  `--no-vendor-extensions`) have no equivalent and are not needed:
  `mix openapi.dump` never starts the app and writes no `x-struct` or
  `x-validate` keys.
- In aliases that dump several OpenAPI documents (one per spec module),
  re-enable the task between calls with
  `Mix.Task.reenable("openapi.dump")`.
- If the project keeps dumped documents in its sources (for a client
  generator, a front-end, docs), regenerate them with the new alias in
  phase 10 and review their diff with `scripts/spec_diff.sh`. Keep the steps that run
  after the dump in the alias (sorting scripts…).

## Expected differences in the OpenAPI document

Compare the old and new documents with `scripts/spec_diff.sh`. Differences you
should expect, and explain, are:

- `openapi: "3.0.x"` → `"3.1.1"`. `nullable` becomes type unions,
  `example` becomes `examples`.
- Operations that were duplicated by OpenApiSpex are gone: PATCH twins of
  PUT operations (when using the `Oaskit.Controller.use_operation/3` macro),
  catch-all routes reusing an
  API action, and operationIds suffixed with `" (2)"` are back to their name.
- operationIds of operations without an explicit `operation_id` change,
  unless they were pinned (phase 2).
- Component names:
  - untitled JSV struct modules: full module name instead of the last module
    segment (add `title:`);
  - duplicate titles: `Name` and `Name_1` instead of one silently replacing
    the other;
  - inline schemas with a `title` (formerly inline `%OpenApiSpex.Schema{}`)
    are no longer hoisted into components;
  - base schemas of flattened `allOf` modules are no longer referenced (see
    `schemas.md`, "Top-level allOf").
- The document size can change a lot (in one migrated app it went from
  1.4 MB to 560 KB with the same operations). Compare operations and
  components, not sizes.
- Server URL: trailing `/`, and defaults for the parts missing from the
  endpoint config (see `Oaskit.Spec.Server.from_config/2` above).
  OpenApiSpex also wrote an empty `"variables": {}`.
- With `spec_diff.sh --deep`: parameter schemas without `nullable` (see
  `controllers.md`, "Parameters"). `--deep` ignores empty `required` lists:
  OpenApiSpex dropped them from the document, Oaskit keeps what the schema
  map declares (`required: []` after `%{base | required: []}`).
- `requestBody.required` set to `true` on the request bodies that were
  optional (`spec_diff.sh` lists them per operation), if kept in phase 0.
- Response statuses declared or corrected in phase 8.

Anything else is a regression to investigate.
