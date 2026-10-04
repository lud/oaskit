# Troubleshooting

Symptoms seen during real migrations, grouped by phase. Names are defined in
`SKILL.md`, "Names used in this skill".

## Compilation

| Symptom | Cause | Fix |
|---|---|---|
| `KeyError key :required not found` (or `:examples`, `:properties`) while compiling a JSV schema module | `Module.json_schema().required` on a schema map without that key. `%OpenApiSpex.Schema{}` returned `nil` | `Map.get(Module.json_schema(), :required, [])` (`rewrite_lib.exs` does it for `Module.schema().required`/`.example`. Check hand-written code) |
| `ArgumentError ... 1st argument: not a nonempty list` (from `hd/1`) around `examples` | An example taken from a schema without examples | `hd(Map.get(Module.json_schema(), :examples, [nil]))`, or drop the example |
| `schema given to defschema/1 must define the :object type` | Array, enum or `oneOf` schema given to `defschema`, or `type: [:object, :null]` | A plain JSV schema module defining `json_schema/0` (`schemas.md`, "Modules that are not objects"), or remove `nullable` and wrap each reference to that module with `nullable(Module)` (`schemas.md`, "nullable") |
| `schema given to defschema/1 must include a properties key` | Object without `properties` (pass-through, or `allOf`), or a property written next to `properties` | `schemas.md`, "Modules the script does not convert", and "Mistakes revealed by the stricter tooling" |
| `schema given to defschema/1 must use known keys only in :required, unknown keys: [...]` | `required` lists keys absent from `properties` | Declare them or remove them from `required` |
| `BadMapError ... got: MyApp.Schemas.Foo` | Map functions applied to a module reference (`Foo \|> Map.put(...)`) after `Module.schema()` → `Module` | `nullable(Foo)`, `Map.merge(Foo.json_schema(), ...)`, or `Foo.json_schema() \|> Map.put(...)` |
| `module attribute @derive was set but never used` | A shared `use` macro adds `@derive` to modules that no longer define a struct | Derive from `@before_compile` only when the module defines a struct (`schemas.md`) |
| `imported JSV.Schema.Helpers.x/n conflicts with local function` | `use JSV.Schema` imports all `JSV.Schema.Helpers` functions | `import JSV, only: [defschema: 1]` in that module |
| `nullable/1 expected a schema map or a schema module, got: MyApp.Schemas.Foo` (or another error saying that a module is not a schema module) for a module that looks right | `JSV.Schema.Helpers.nullable/1` loads the module with `Code.ensure_compiled/1`, which fails when a module that `Foo` depends on did not compile (often a module left as is and reported by `rewrite_lib.exs`, e.g. a top-level `allOf`) | Fix the other compile errors first (every `REPORT` line), then compile again |
| Errors in spec modules, routers and controllers before the end of phase 6 (`OpenApiSpex.Info.__struct__/1 is undefined`…) | They still use OpenApiSpex until phases 5 and 6 | Expected: `mix compile` is the gate of phase 6 |
| `module OpenApiSpex is not loaded and could not be found` (or `you must require OpenApiSpex`) | A module left as is by `rewrite_lib.exs` (reported) still calls `OpenApiSpex.schema/1` | Rewrite it by hand |
| `key :in is required when building Oaskit.Spec.Parameter` | A parameter without `in:` (OpenApiSpex defaulted to `:query`), usually built by a project function | Add `in: :query` (`controllers.md`, "Parameters") |
| `undefined function schema/1` | `import OpenApiSpex` replaced by `use JSV.Schema`, with a `schema(...)` call left as is (reported: its argument is not a map literal) | `defschema ...` or `def json_schema` (`schemas.md`, "Schemas built by a function") |
| Warnings that `schema/0` of a JSV struct module is deprecated | Code still calls `schema/0`, which `defschema` defines as a deprecated alias of `json_schema/0` | `Module.json_schema()`, or `Module` where a schema is expected |

## Building the operations (boot, first validated request, `Oaskit.warmup_spec_cache/2`)

These errors are raised when Oaskit builds the operations and JSV roots: at
boot with the warmup of phase 5, on the first validated request, or with the
`Oaskit.warmup_spec_cache/2` check of the phase 7 gate in `SKILL.md`. `mix openapi.dump` does not build them and
succeeds anyway.

`JSV.BuildError` messages locate the schema by component name
(`#/components/schemas/ApplicationHistoryItem/properties/...`), not by
module. Find the module with its title (`grep -rn 'title: "ApplicationHistoryItem"'
lib`), or with the `x-struct` of the component in the old OpenAPI document
(`jq -r '.components.schemas["ApplicationHistoryItem"]["x-struct"]' $WORK/old_ApiSpec.json`).
A component named after a full module name is a schema module without title.

| Symptom | Cause | Fix |
|---|---|---|
| `ArgumentError: duplicate operation id "..."` | One action on several routes (PUT + PATCH from `resources`, catch-all routes) | `controllers.md`, "One controller action, several routes" |
| `JSV.BuildError: could not build JSON schema at #..., {:unsupported_format, "datetime"}` | Format unknown to JSV/Oaskit, OpenApiSpex ignored it (the inventory report lists them) | `schemas.md`, "Formats" |
| `JSV.BuildError ... invalid_sub_schema` pointing to `.../properties/oneOf` | A schema keyword used as a property name (the inventory report lists them) | `schemas.md`, "Mistakes revealed by the stricter tooling" |
| `could not build url from endpoint ... configuration` | `Oaskit.Spec.Server.from_config/2` needs `url: [host: ...]` in the endpoint config | Add it, or write `servers` by hand |
| `operation with id "..." was not built` | The spec provider plug of the route gives a spec module whose `paths` do not include the route (e.g. excluded by the `:filter` option of `Oaskit.Spec.Paths.from_router/2`) | Fix the filter, or use the right spec module in that pipeline |

## Requests

| Symptom | Cause | Fix |
|---|---|---|
| `Plug.Conn.AlreadySentError` in actions, after a validation error | The error handler does not call `Plug.Conn.halt/1` | Halt in `handle_error/3` (`errors.md`) |
| 401 on every request to some endpoints, with a warning about security | Operations declare `security:` and the validation plug has no `:security` option | `security: false`, or a security plug (`controllers.md`) |
| 400 `missing parameter X in path` on a route that has the parameter under another name | OpenApiSpex `name:` option: Oaskit uses the key | Rename the key (`controllers.md`, "Parameters") |
| Log warning `parameter "x" in header (...) will reject every value` when the operations are built | The parameter schema type has no `string` and Oaskit has no cast for it (e.g. array items written as `oneOf`) | Give the schema a type Oaskit casts, or a schema that accepts the raw string (Oaskit limitations guide, "Query string parameters cast", in `links.md`) |
| An empty JSON body (`{}`) reaches the action without validation | The request body is `required: false` | Keep `required: true` (the default of the Oaskit shortcut `request_body: User`, see `controllers.md`, "Request bodies: the shortcut makes them required") |
| `FunctionClauseError` / `nil` where code read OpenApiSpex-cast params with atom keys | `replace_params: true` controllers, or inline object schema maps now cast with string keys | `controllers.md`, "Phoenix params vs cast values" |
| `Protocol.UndefinedError` for `JSV.Normalizer.Normalize` | Structs given to `JSV.Normalizer.normalize/1` | `casting-outside-requests.md`, "Input: JSON-shaped data" |
| No warning at all but a controller is not validated | The controller has no validation plug, or the action has `operation :action, false` | Add the validation plug, or remove `operation :action, false` |
| Warning `Controller X has no operation defined for action :y` | The validation plug runs for an action without operation | Add an operation, or `operation :y, false` |

## Tests

See `testing.md`, "Typical failures after the switch".
