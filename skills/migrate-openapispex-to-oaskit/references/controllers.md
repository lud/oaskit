# Controllers: OpenApiSpex → Oaskit

Names (validation plug, Phoenix params, cast values, error handler…) are
defined in `SKILL.md`, "Names used in this skill".

## Mapping

| OpenApiSpex | Oaskit | Rewritten by `rewrite_lib.exs` |
|---|---|---|
| `use OpenApiSpex.ControllerSpecs` | `use Oaskit.Controller` | yes |
| `plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false, render_error: MyRenderer` | `plug Oaskit.Plugs.ValidateRequest, error_handler: MyAppWeb.ApiErrorHandler, html_errors: false` | yes (`--error-handler`), `REPORT` for dropped options. `html_errors: false` keeps JSON error bodies for browser-like clients, as OpenApiSpex did (see `errors.md`) |
| `operation :action, summary: ..., description: ..., operation_id: ..., tags: [...]` | same | unchanged |
| `tags ["Users"]` (shared tags macro) | same (`Oaskit.Controller.tags/1`) | unchanged |
| `operation :action, false` | same | unchanged |
| `parameters: [id: [in: :path, schema: %Schema{type: :string}, description: ..., required: true]]` | same keyword syntax, schema as a schema map | yes (the schema part) |
| parameter without `in:` | `in: :query` (OpenApiSpex's default, required by Oaskit) | yes (`INFO`) |
| `id: [in: :path, name: :run_id, ...]` | `run_id: [in: :path, ...]` (Oaskit names the parameter after the key and ignores `name:`) | yes (`INFO`) |
| parameter schema with `nullable: true` | `nullable` removed, see "Parameters" | yes (`INFO`) |
| `parameters: helper(...)`, `responses: helper(...)` | see "Parameters" and "Responses built by a function" | `REPORT` |
| response `{"Description", "application/json", User}` | `{User, description: "Description"}` | yes |
| response `{"Description", "text/plain", nil}` | `[description: "Description"]` | yes |
| response `{"Description", "text/csv", User}` | `[description: "Description", content: %{"text/csv" => [schema: User]}]` | yes |
| response `"Description"` (a string alone) | `[description: "Description"]` | yes |
| `request_body: {"Description", "application/json", User}` | `request_body: {User, description: "Description"}` (**required: true**) | yes, `REPORT` |
| `request_body: {"Description", "application/json", User, required: true}` | `request_body: {User, description: "Description"}` | yes |
| `security: [%{"bearerAuth" => []}]` | same, but see "Security" | unchanged, `REPORT` |

In this table and below, `User` is a JSV schema module and `MyRenderer` the
module of your OpenApiSpex `:render_error` plug.

Shorthand forms of the `Oaskit.Controller.operation/2` macro (called "the
Oaskit shortcut" in this skill):

- `request_body: User` or `{User, opts}`: `application/json` content,
  `required: true` by default. A schema map must be wrapped: `{%{type: :object, ...}, []}`.
- `responses: [ok: User]`: `application/json` content. The description comes from the
  schema's `description` (or "no description"). Override it with
  `{User, description: "..."}`.
- `:default` can be used as a response status.

## Parameters

`rewrite_lib.exs` converts the parameters written literally in the
`parameters:` option (keyword list or map). For parameters built by a
function (`parameters: Utils.query_params(page: :integer)`, `[id: ...] ++
Pagination.params()`), it removes `nullable` from the `%OpenApiSpex.Schema{}`
structs found in the arguments of the call and renames the keys after their
`name:` (`id: [name: :run_id]` → `run_id: [...]`). Anywhere in the code, it
also removes `nullable` from the schema of a keyword list that has both `in:`
and `schema:` (a parameter the function builds). Check the rest of the
function by hand with the rules below: a missing `in:`, a `name:` computed
from something else than the key, parameters written another way.

- `in:` is required by Oaskit (compile error `key :in is required when
  building Oaskit.Spec.Parameter`). OpenApiSpex defaulted to `:query`.
- Oaskit uses the key as the parameter name. An OpenApiSpex `name:` option
  that differs from the key declared a parameter that the route does not
  have: requests fail with `missing parameter id in path`.
- No `nullable` in parameter schemas. A path, query or header value is a
  string, never `null`. Oaskit casts the strings of parameters with a
  single-type schema (`type: :integer` → `?page=1` becomes `1`), not of a
  type union: `type: [:integer, :null]` rejects `?page=1` with `value is not
  of type integer or null`. An optional parameter is written `required:
  false` (the default for query and header parameters).

## Responses built by a function

`Oaskit.Controller.operation/2` evaluates its options in the controller
module body, at compile time, like OpenApiSpex. A function of another module
that builds `responses:` (e.g. adding the common error statuses) keeps
working once it returns Oaskit responses: a keyword list or map of status to
`{Schema, description: "..."}`, `[description: "..."]`, or `Schema` alone.

When the arguments of the call contain OpenApiSpex response tuples
(`Utils.responses(ok: {"User", "application/json", User}, not_found: true)`),
`rewrite_lib.exs` rewrites those tuples to Oaskit responses
(`ok: {User, description: "User"}`) and reports the call. Then change the
function itself: its own tuples, and the shape it expects from its
arguments.

## Request bodies: the shortcut makes them required

OpenApiSpex request body tuples (`{description, content_type, schema}`)
default to `required: false`. The Oaskit shortcut (`request_body: User` /
`{User, opts}`) defaults to `required: true` (a full `request_body: [content: ..., required: ...]`
declaration defaults to `false`, as in OpenAPI). With `required: false`, Oaskit
**skips body validation** when the body is empty (`""`, `nil`, or `%{}`, which
is what `Plug.Parsers` gives for an empty JSON body). So an endpoint that
expected 422 errors on `{}` must stay `required: true`. Keep the default
unless an endpoint really accepts an empty body, then write `{User,
description: "...", required: false}`.

## Phoenix params vs cast values

`Oaskit.Plugs.ValidateRequest` never modifies the `params` given to the
action, nor `conn.body_params`, `conn.path_params` or `conn.query_params`
(the Phoenix params). It stores cast values in `conn.private.oaskit`, read
with:

- `Oaskit.Controller.body_params(conn)`: the cast body (a struct when the
  request body schema is a JSV struct module);
- `Oaskit.Controller.path_param(conn, :id)`,
  `Oaskit.Controller.query_param(conn, :page, default)`,
  `Oaskit.Controller.header_param(conn, :"x-request-id")`: cast parameters
  (integers, booleans, formats such as `date` cast to `Date`).

These functions are imported by `use Oaskit.Controller`, so controllers call
them without the module prefix (`body_params(conn)`). Do not confuse
`body_params(conn)` (cast values) with `conn.body_params` (Phoenix params).

Cast values also have their `format` cast, in bodies and parameters
(Oaskit calls `JSV.validate/3` with the `cast_formats: true` option): `date` → `Date`,
`date-time` → `DateTime`, `time` → `Time`, `uri` → `URI`, `ipv4` → a tuple…
Code moving from Phoenix params (strings) to cast values must expect these
types. The Phoenix params keep the original strings.

What each OpenApiSpex setup becomes:

- **`replace_params: false`** (most apps): controllers read the Phoenix
  params, which is exactly Oaskit's behaviour. Nothing to change. Moving to
  the cast values is a good follow-up: types are already cast, struct fields
  are known. Do it once the migration is green.
- **`replace_params: true`** (the OpenApiSpex default, reported by
  `rewrite_lib.exs`): OpenApiSpex replaced the action `params` with
  OpenApiSpex-cast params (atom keys) and `conn.body_params` with the
  OpenApiSpex-cast body. Code
  matching `%{id: id}` in the action head, or reading `conn.body_params` as a
  struct, must move to `Oaskit.Controller.path_param(conn, :id)` /
  `Oaskit.Controller.body_params(conn)` (or to string keys: `%{"id" => id}`).

The cast body of an inline object schema map has **string keys**. OpenApiSpex
returned atom keys. Code like `Enum.map(body.items, & &1.name)` needs a JSV
struct module for the items (see `schemas.md`, "JSV struct modules
(`defschema`)", the `MyApp.Schemas.Order` example) or string keys.

## `conn.private.open_api_spex`

The OpenApiSpex plugs stored data in `conn.private.open_api_spex`. The
inventory lists the code reading it:

- `conn.private.open_api_spex.body_params` (the OpenApiSpex-cast body, set
  even with `replace_params: false`) → `Oaskit.Controller.body_params(conn)`.
  The cast value differs: a JSV struct for JSV struct modules, string keys
  for inline object schema maps (see above);
- `conn.private.open_api_spex.spec_module` (often in `ConnCase`) →
  `Oaskit.Plugs.SpecProvider.fetch_spec_module!(conn)`;
- `OpenApiSpex.Plug.Cache.adapter().erase(Spec)` (tests that change the
  spec): Oaskit caches each built spec in `:persistent_term`. Build it
  without the cache with `Oaskit.build_spec!(Spec, cache: false)`, or drop
  that code if it only served OpenApiSpex. When it is the last expression
  of a function, keep the function's return value (callers may match on
  `:ok`).

## Security

If an operation (or the top-level `security` key of the OpenAPI document) declares security,
`Oaskit.Plugs.ValidateRequest` calls the plug given in its `:security` option.
**Without that option it logs a warning and answers 401.** If authentication
already happens elsewhere (a router pipeline plug, as is common with
OpenApiSpex apps):

```elixir
plug Oaskit.Plugs.ValidateRequest, error_handler: MyAppWeb.ApiErrorHandler, security: false
```

To move authorization into Oaskit instead, read "Security plugs (`:security`
option)" in `links.md`.

## Controllers with operations but no validation plug

`OpenApiSpex.TestAssertions.assert_schema/3` validated responses by schema
title, without the request going through the validation plug. `Oaskit.Test.valid_response/3`
finds the operation through `conn.private.oaskit`, which only
`Oaskit.Plugs.ValidateRequest` sets. The inventory report lists these controllers under "operations but no
CastAndValidate".
Add the validation plug (after authentication/permission plugs, like in other
controllers), or keep `json_response/2` in their tests.

## One controller action, several routes

Oaskit raises `ArgumentError: duplicate operation id "..."` when building the
operations (first validated request, not `mix openapi.dump`) if one action
is reachable through several routes.
OpenApiSpex accepted it and renamed the second operationId `"<id> (2)"`. The
inventory (`--routes`) lists these actions.

The old OpenAPI documents list them too: OpenApiSpex suffixed the
second operationId with `" (2)"`:

```sh
jq -r '[.paths[][] | objects | .operationId // empty] | .[] | select(endswith(" (2)"))' $WORK/old_ApiSpec.json
```

**PUT and PATCH from `resources`** (`resources "/users", UserController`
routes `:update` on both verbs): declare the operation for one verb, and make
the other verb validate with the same operation without adding it to the
document:

```elixir
use_operation :update, "UpdateUser", method: :patch

operation :update,
  method: :put,
  operation_id: "UpdateUser",
  request_body: UserParams,
  responses: [ok: User]

def update(conn, params) do
  # ...
end
```

The `Oaskit.Controller.use_operation/3` macro maps an action (and verb) to an
existing operationId. The `operation_id:` option of the `operation` macro must
be explicit here. Declare the operation on the verb whose operationId had no
`" (2)"` suffix in the old document: the document keeps the same path and
method for that operationId.

**The same action under unrelated paths** (e.g. a catch-all browser route
reusing an API action): keep the API route in the document with the
`:filter` option of `Oaskit.Spec.Paths.from_router/2` in the spec module:

```elixir
paths: Paths.from_router(MyAppWeb.Router, filter: &String.starts_with?(&1.path, "/api/"))
```

## JSON array request bodies

`Plug.Parsers.JSON` puts non-object JSON bodies (arrays, scalars) under a
`"_json"` key: `conn.body_params == %{"_json" => [...]}`. OpenApiSpex
unwrapped it. Oaskit validates `conn.body_params` as is, so an array schema
fails on the top-level body value (instance location `#`: "value is not of
type array"). Unwrap before validation:

```elixir
defmodule MyAppWeb.Plugs.UnwrapJsonBody do
  @moduledoc """
  Plug.Parsers.JSON wraps non-object JSON bodies under a "_json" key.
  Oaskit validates conn.body_params as is, so array bodies are unwrapped
  before Oaskit.Plugs.ValidateRequest.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{body_params: %{"_json" => body} = body_params} = conn, _opts)
      when map_size(body_params) == 1 do
    %{conn | body_params: body}
  end

  def call(conn, _opts), do: conn
end
```

In the controller, before the validation plug, limited to the actions that
take an array:

```elixir
plug MyAppWeb.Plugs.UnwrapJsonBody when action in [:bulk_update]
plug Oaskit.Plugs.ValidateRequest, error_handler: MyAppWeb.ApiErrorHandler
```

After `MyAppWeb.Plugs.UnwrapJsonBody`, `conn.body_params` is the list
itself. Change the actions that read `conn.body_params["_json"]` (or use `Oaskit.Controller.body_params(conn)`
for the cast value). Note that `Plug.Conn`'s typespec declares `body_params` as a map.

## Operation IDs

"operationId" is the field of the OpenAPI document, `operation_id:` the option
of the `operation` macro that sets it.

| | Default operationId |
|---|---|
| OpenApiSpex | `"#{inspect(module)}.#{action}"`, e.g. `"MyAppWeb.UserController.update"` |
| Oaskit | `"#{underscore(last module segment)}_#{action}_#{hash}"`, e.g. `"user_update_S6XE5MI"` (the `Controller` suffix is removed) |

Operations without an explicit `operation_id:` get a new operationId after
the migration. That is visible to anything generated from the OpenAPI
document (clients, tools). `scripts/pin_operation_ids.exs` writes the
OpenApiSpex default explicitly. operationIds must be unique in an OpenAPI
document.

## Where to put `use Oaskit.Controller` and the validation plug

Rewriting each controller in place (as `rewrite_lib.exs` does) gives the
smallest diff. When the web module already has them in a function such as
`api_controller/0` (inside its `quote`), the script rewrites them there, and
every controller using that function is concerned. Later, both can move to a dedicated `api_controller/0` function
in the `MyAppWeb` module (see "`api_controller/0` in the web module" in
`links.md`). Keep plug order in mind: the validation plug should run after
authentication and permission plugs.
