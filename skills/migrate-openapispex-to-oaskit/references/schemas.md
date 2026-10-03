# Schemas: OpenApiSpex → JSV

Names (OpenApiSpex schema module, JSV schema module, JSV struct module,
schema map…) are defined in `SKILL.md`, "Names used in this skill".

## Mapping

| OpenApiSpex | JSV | Rewritten by `rewrite_lib.exs` |
|---|---|---|
| `require OpenApiSpex` | `use JSV.Schema` (imports the `JSV.defschema` macros and the `JSV.Schema.Helpers` functions such as `nullable/1`) | yes (removed when the module needs neither) |
| `alias OpenApiSpex.Schema`, `alias OpenApiSpex.{Discriminator, Schema}` | nothing | yes |
| `%Schema{type: :string}` | `%{type: :string}` | yes |
| `%Discriminator{propertyName: "type"}` | `%{propertyName: "type"}` | yes |
| `OpenApiSpex.schema(%{type: :object, properties: ...})` | `defschema %{type: :object, properties: ...}` | yes |
| `OpenApiSpex.schema(%{type: :array, ...})` (or a string enum, or a top-level `oneOf`/`anyOf`) | `def json_schema do %{type: :array, ...} end` | yes |
| `OpenApiSpex.schema(%{allOf: ...})`, object without `properties` | see below | no, `REPORT` |
| `OpenApiSpex.schema(%{...}, struct?: false)` (any type) | `def json_schema do %{...} end` (a plain JSV schema module: no struct, as before. An object is cast to a map with string keys, OpenApiSpex gave atom keys) | yes |
| `OpenApiSpex.schema(%{...}, derive?: false)` | as without the option (`defschema/1` derives nothing) | yes |
| `%{...} \|> OpenApiSpex.schema()` | as `OpenApiSpex.schema(%{...})` | yes |
| `import OpenApiSpex` and bare `schema(%{...})` calls | `use JSV.Schema`, and the calls as `OpenApiSpex.schema(%{...})` | yes |
| `OpenApiSpex.schema(helper(...))` (the map is built by a function) | `defschema helper(...)` or `def json_schema, do: helper(...)` | no, `REPORT` (see "Modules the script does not convert") |
| `def schema do %Schema{...} end` (a schema module written by hand, no `OpenApiSpex.schema/1`) | `def json_schema do %{...} end` | yes (`INFO`) |
| `var = Module.schema()` (also `%Schema{} = var = Module.schema()`) | `var = Module.json_schema()`: the value is used as a map | yes |
| `%Schema{} = expr` (a pattern) | `%{} = expr` | yes, `REPORT` in files that still use other OpenApiSpex modules at runtime (the data may be OpenApiSpex structs, see `casting-outside-requests.md`, "Third-party OpenAPI 3.0 documents") |
| `Module.schema()` used as a sub-schema | `Module` (a module reference) | yes |
| `Module.schema().properties` | `Module.json_schema().properties` | yes |
| `Module.schema().required` | `Map.get(Module.json_schema(), :required, [])` | yes |
| `Module.schema().example` | `hd(Map.get(Module.json_schema(), :examples, [nil]))` | yes |
| `%{Module.schema() \| nullable: true}`, `Module.schema() \|> Map.put(:nullable, true)`, `Map.put(Module.schema(), :nullable, true)` | `nullable(Module)` | yes |
| `Module.schema() \|> Map.put(:nullable, false)`, `Map.put(Module.schema(), :nullable, false)` | `Module` | yes |
| `Map.put(expr, :nullable, true)` (piped or not, e.g. `Module.schema().properties.id`) | `nullable(expr)` | yes |
| `nullable: true` | see "nullable" below | yes, except without `type` |
| `example: value` | `examples: [value]` | yes |
| `format: :"date-time"`, `:uuid`, `:email`, … | unchanged | n/a |

In this table, `Module` is an OpenApiSpex schema module written literally,
which becomes a JSV schema module.

Why `.required` and `.example` need `Map.get`: `%OpenApiSpex.Schema{}` is a
struct, so a missing key reads as `nil`. `Module.json_schema()` returns a
schema map, so
`Module.json_schema().required` raises `KeyError` (at compile time when used inside
a schema definition) if `Module` has no `required` key.

## JSV struct modules (`defschema`)

```elixir
defmodule MyApp.Schemas.User do
  use JSV.Schema

  defschema %{
    title: "User",
    type: :object,
    properties: %{
      id: %{type: :string, format: :uuid},
      name: %{type: :string},
      nickname: %{type: [:string, :null]}
    },
    required: [:id, :name]
  }
end
```

Rules of `JSV.defschema/1` with a map. `defschema` raises at compile time
when the first three are broken:

- `type` must be exactly `:object`. A list such as `[:object, :null]` is
  rejected.
- `properties` must be a map.
- Every key in `required` must be in `properties`. JSON Schema allows
  requiring an undeclared key, OpenApiSpex allowed it, `defschema` does not.
  Either declare the property or remove the key from `required`. Structs
  defined by OpenApiSpex schema modules dropped undeclared keys when casting,
  so removing the key never changed the output.
- `required` keys become `@enforce_keys` of the struct: code building the
  struct literally (`%MyApp.Schemas.User{}`) must give them.
- No default `title`. Oaskit uses the title as the component name, and falls
  back to the full module name. OpenApiSpex defaulted to the last module
  segment. Add `title:` to keep component names.
- Struct keys are the `properties` keys. Valid data is cast to the struct and
  undeclared keys are dropped (set the `@additional_properties :field_name`
  attribute before `defschema` to collect them).
- `defschema/1` does not derive `JSON.Encoder`. `OpenApiSpex.schema/1`
  derived `Jason.Encoder` when Jason was available. If you JSON-encode the structs,
  add `@derive JSON.Encoder` (or `Jason.Encoder`) before `defschema`.
- `use JSV.Schema` imports all `JSV.Schema.Helpers` functions (`string/0`,
  `integer/0`, `object/0`, `format/1`, `ref/1`…). If a module defines a local
  function with the same name and arity, compilation fails with "imported …
  conflicts with local function". Use `import JSV, only: [defschema: 1]`
  (plus `import JSV.Schema.Helpers, only: [nullable: 1]` if needed) in that
  module.

`JSV.defschema/1` with a **keyword list** of properties, and the
module-defining `JSV.defschema/2,3` macro (`defschema Name, props` or
`defschema Name, "description", props`), behave differently:

- properties are required unless wrapped with `optional/1`;
- the title is set: the last module segment for `defschema/1`, the module
  name as written for `defschema/2,3` (`Line` below);
- `defschema/2,3` derives `JSON.Encoder` (and `Jason.Encoder` when
  available).

The module-defining `JSV.defschema/2,3` is the shortest way to write nested
objects as structs:

```elixir
defmodule MyApp.Schemas.Order do
  use JSV.Schema

  # Sub-objects first, with the keyword syntax. Each one is a JSV struct module
  # (MyApp.Schemas.Order.Line, MyApp.Schemas.Order.Address).
  defschema Line,
    sku: string(),
    quantity: integer(minimum: 1)

  defschema Address,
    street: string(),
    city: string(),
    zip: optional(string())

  # The wrapper last, referencing the sub-objects by module.
  defschema %{
    title: "Order",
    type: :object,
    properties: %{
      id: %{type: :string, format: :uuid},
      lines: %{type: :array, items: Line},
      shipping: nullable(Address)
    },
    required: [:id, :lines]
  }
end
```

Use this when code reads nested values with atom keys (`line.sku`): only JSV
struct modules (and the `JSV.Schema.Helpers.aprops/2` and `arprops/2`
functions, see `casting-outside-requests.md`, "Output differences") produce
atom keys. Inline object schema maps
are cast to maps with **string** keys. OpenApiSpex returned atom keys for
them.

## Modules that are not objects

`JSV.defschema` only defines objects. Array schemas, string enums and
top-level `oneOf`/`anyOf` become plain JSV schema modules (see the names table
in `SKILL.md`):

```elixir
defmodule MyApp.Schemas.UserList do
  def json_schema do
    %{title: "UserList", type: :array, items: MyApp.Schemas.User}
  end
end
```

They define no struct. If the module used to get `@derive` attributes from a
shared `use`/`__using__` macro, the compiler warns "module attribute @derive
was set but never used". Derive only when the module defines a struct, for
example from an `@before_compile` hook in that macro:

```elixir
defmacro __before_compile__(env) do
  if Module.defines?(env.module, {:__struct__, 0}) do
    quote do
      require Protocol
      Protocol.derive(JSON.Encoder, __MODULE__)
    end
  end
end
```

## nullable

OpenAPI 3.1 has no `nullable`. The rules applied by `rewrite_lib.exs`:

| OpenApiSpex | JSV |
|---|---|
| `type: :string, nullable: true` | `type: [:string, :null]` |
| `type: :string, enum: ["a", "b"], nullable: true` | `type: [:string, :null], enum: ["a", "b", nil]` (in JSON Schema, `null` must also be in `enum`). A `~w(a b)` or `~w(a b)a` enum becomes a list. Any other expression is reported: until `nil` is added by hand, `null` is rejected |
| `oneOf: [A, B], nullable: true` (or `anyOf`) | `oneOf: [%{type: :null}, A, B]` |
| `allOf: [Module], nullable: true` (`Module` as in "Mapping") (with or without `type: :object`) | `anyOf: [%{type: :null}, Module]`, without `type` (`type: :object` would reject null) |
| `nullable: false` | removed |
| module reference made nullable (`%{Module.schema() \| nullable: true}`) | `nullable(Module)` → `%{anyOf: [%{type: :null}, Module]}` |
| any other expression made nullable (`my_schema() \|> Map.put(:nullable, true)`, `Map.put(Module.schema().properties.id, :nullable, true)`) | `nullable(my_schema())`. On a schema map, `JSV.Schema.Helpers.nullable/1` adds `:null` to `type` and `nil` to `enum`, and `%{type: :null}` to `anyOf`/`oneOf`. A schema map with none of these keys is returned unchanged (it already accepts null). |

Reported, not rewritten:

- **`nullable: true` without `type`** (e.g. `%Schema{items: Module, nullable:
  true}`, `%Schema{description: "...", nullable: true}`). OpenApiSpex did not
  cast or validate a value whose schema has no `type`: the value passed
  through untouched. Choose:
  - add the intended type (`type: [:array, :null], items: Module`). The value is
    now validated and cast: items become `Module` structs, and declared but absent
    keys appear as `null` in JSON output;
  - or keep the old behaviour with a schema that applies nothing: drop
    `nullable` **and** the keywords that apply to sub-values (`items`,
    `properties`, `additionalProperties`…). In JSON Schema these keywords
    apply whatever the type: `%{items: Module}` without `type` still
    validates and casts the items of any array value. Keep the documentation
    keys (`description`).

  Prefer the first option when the value really has that type: the OpenAPI
  document then describes it for clients. Then run the tests. The new cast
  only changes data where something casts with this schema: request bodies
  and parameters (cast values), and code casting outside requests
  (`casting-outside-requests.md`). Oaskit does not cast responses: the
  valid_response helper only validates them.
- **Top-level nullable object module** (`OpenApiSpex.schema(%{type: :object,
  nullable: true, ...})`). The script removes `nullable` from the module
  (`defschema` needs `type: :object`). With OpenApiSpex, nullability was
  carried by the referenced component itself. Now **wrap every reference**
  to that module with `nullable(Module)`. Find references with `grep -rn
  "Module\b"`.

## Modules the script does not convert

`rewrite_lib.exs` rewrites the content of these modules (`%Schema{}` structs,
`Module.schema()` references, `example`…) but keeps the
`OpenApiSpex.schema/1` call. Replace that call by hand.

### Top-level allOf

With or without `type: :object`. `JSV.defschema` needs a `properties` map, so
it cannot express "Base + extra properties". Choose:

- Flatten into a JSV struct module (keeps struct casting):

  ```elixir
  # before: allOf: [BaseQuestion, %{properties: %{type: ...}, required: [:type]}]
  defschema %{
    title: "TextQuestion",
    type: :object,
    properties:
      Map.put(BaseQuestion.json_schema().properties, :type, %{type: :string, enum: ["text"]}),
    required: Enum.uniq(Map.get(BaseQuestion.json_schema(), :required, []) ++ [:type])
  }
  ```

  Use `Map.merge/2` for several extra properties. Append the `required` list
  of each extra schema to the base's, and keep the other keys of the extra
  schemas (`description`, `examples`…): leaving them out silently drops
  requirements and documentation. The base module is not referenced in the
  OpenAPI document anymore.
- Keep `allOf` in a plain JSV schema module (`def json_schema, do:
  %{allOf: [Base, %{...}]}`). Valid data is not cast to a struct of this
  module, so check what code reads the cast value.

### Object schemas without properties

`OpenApiSpex.schema(%{type: :object, ...})` without `properties` accepted any
object and passed data through, even though it defined a struct. A
`defschema` with an empty `properties` map would cast to an empty struct and
**drop every key**. Use a plain JSV schema module:
`def json_schema, do: %{type: :object, description: "..."}`.
`rewrite_lib.exs` does it (`INFO`), except when the module also has `allOf`,
`anyOf` or `oneOf` (`REPORT`, the call is kept).

Schemas that copy the properties of such a module (`properties:
Other.schema().properties`, rewritten to `Other.json_schema().properties`)
got `nil` from OpenApiSpex, so they were pass-through objects too. Now
`Other.json_schema().properties` raises `KeyError` at compile time. The same
holds for a module with a top-level `allOf` (no `properties` key either).
`rewrite_lib.exs` reports these copies when it finds the other module in the
rewritten paths. Turn the copying module into a plain JSV schema module as
well (or give it real properties, which turns on validation that never ran).

### Schemas built by a function

`OpenApiSpex.schema(api_error_schema("NotFound", "not_found"))`: the script
rewrites the structs inside the function (`%Schema{}` → maps) but not the
call. `JSV.defschema/1` accepts any expression that returns a map at compile
time, so `defschema api_error_schema("NotFound", "not_found")` works when
the function returns an object with `properties` (the rules of "JSV struct
modules" apply to the returned map). Otherwise write `def json_schema, do:
api_error_schema(...)`.

The same holds for modules defined in a loop (`defmodule name do ... end`
inside `Enum.each/2`): replace the `OpenApiSpex.schema/1` call in the loop
body.

### `OpenApiSpex.schema/2` with other options, `%Schema{x | ...}` updates

Rewrite by hand with the rules above.

## Formats

JSV validates formats with the roots Oaskit builds, and **raises on unknown
formats when Oaskit builds the operations** (first validated request, or the
`Oaskit.build_spec!/2` check of the phase 7 gate in `SKILL.md`), not at
compile time and not in `mix openapi.dump`. OpenApiSpex ignored unknown
formats. The inventory lists formats unknown to JSV and Oaskit. Typos seen
in practice: `:date_time`/`:datetime` (→ `:"date-time"`), `"url"` (→
`:uri`), `:uiid`. Check what the field contains before fixing: a `format` on
the wrong field (e.g. a name with a uuid format) should be removed.

Known formats: JSV's (date, date-time, duration, email, hostname, ipv4, ipv6,
iri, iri-reference, json-pointer, regex, relative-json-pointer, time, uri,
uri-reference, uri-template, uuid, unknown) and Oaskit's
(`Oaskit.JsonSchema.Formats`: int32, int64, float, double, binary, byte,
password, decimal…).

### Formats OpenApiSpex did not check

OpenApiSpex only checked date, date-time, uuid and byte. JSV also checks
email, uri, hostname, ipv4… Requests with values that OpenApiSpex let
through (an invalid email checked later by an Ecto changeset, for example)
are now rejected by the validation plug, with the error handler's body
instead of the changeset error. Decide (phase 0):

- keep the new validation, and update the tests that expected the later
  error;
- or keep the formats in the OpenAPI document without checking them: a
  format validator module that accepts any string for those formats, put
  first in the `:formats` option of each spec module.

```elixir
defmodule MyAppWeb.UncheckedFormats do
  @moduledoc """
  Formats documented in the OpenAPI document but not validated in requests,
  as with OpenApiSpex.
  """
  @behaviour JSV.FormatValidator

  @impl true
  def supported_formats, do: ["email", "uri"]

  @impl true
  def applies_to_type?(_format, data), do: is_binary(data)

  @impl true
  def validate_cast(_format, data), do: {:ok, data}
end
```

```elixir
defmodule MyAppWeb.ApiSpec do
  use Oaskit

  # spec/0 ...

  @impl true
  def jsv_opts do
    Keyword.update!(super(), :formats, &[MyAppWeb.UncheckedFormats | &1])
  end
end
```

`jsv_opts/0` is an overridable callback of `use Oaskit` (the default returns
`Oaskit.default_jsv_opts/0`). JSV picks the first module of `:formats` that
lists a format. Pass the same options to `JSV.build!/2` for schemas cast
outside requests if needed.

## Mistakes revealed by the stricter tooling

OpenApiSpex accepted any key in `%OpenApiSpex.Schema{}`. The inventory, run
before the phase 3 rewrite, lists two shapes that are almost always bugs:

- an unknown key at the schema level (`type: :object, stages: %Schema{...}`
  instead of under `properties`);
- a schema keyword used as a property name (`properties: %{oneOf: [...]}`
  is a property named `oneOf`, never applied as a keyword).

Fixing them **turns on validation that never ran**. Check that the schema
matches the real data (fix the schema if needed), and check every place that
casts data with it. The faithful alternative is a schema that accepts what
was effectively accepted before (e.g. `%{type: :object}`).

## Titles and components

- Oaskit collects JSV schema modules into `components.schemas`, keyed by
  `title`, falling back to the full module name.
- Same title on two different schemas **of the same OpenAPI document**:
  OpenApiSpex silently kept one (one endpoint then showed the wrong
  schema). Oaskit keeps both and suffixes one of them (`Name_1`), in an
  order unrelated to the one OpenApiSpex kept. Accepting the suffix can
  silently swap the schema behind the name clients know. For each
  duplicate:
  1. find the module OpenApiSpex kept in the old OpenAPI document: its
     component has an `x-struct` key with the module name, printed as
     `Elixir.MyApp.Schemas.Name`
     (`jq -r '.components.schemas["Name"]["x-struct"]' $WORK/old_ApiSpec.json`,
     with the filter in single quotes: zsh reads `[...]` in double quotes);
  2. keep the title on that module, and give the other one a new explicit
     title.
- `rewrite_lib.exs --titles` adds that title (the last module segment) to
  every OpenApiSpex schema module without one, written in the module
  (`INFO` lines list them).
- Untitled OpenApiSpex schema modules had the last module segment as
  title, so `MyApp.Pipeline.List` and `MyApp.Stage.List` collided as `List`.
  Once untitled JSV struct modules are named after the full module name
  they no longer collide, but adding `title: "List"` to both (to keep
  component names) brings the collision back.
- Duplicates only matter inside one OpenAPI document. The inventory lists
  titles shared across the whole project (untitled modules counted with
  their last module segment), and with `--routes`, the titles shared by
  schema modules reachable from the operations of one router: those are
  the ones to fix.
- OpenApiSpex hoisted inline schemas (`%OpenApiSpex.Schema{}` written inside
  another schema) that have a `title` into components. Oaskit keeps inline
  schema maps inline, even with a `title` (same validation, different
  document layout).
- `discriminator` is kept in the document as documentation. JSV ignores it.
  `oneOf` is validated strictly (exactly one branch must match).

## Code that reads schemas at runtime

The rewrite `Module.schema()` → `Module` replaces an inline copy (`%OpenApiSpex.Schema{}`
struct) with a module reference (an atom). Equivalent for Oaskit, but code
that inspects schemas at runtime now sees an atom where it used to see a
struct. For example, code that branches on `is_atom(schema.items)` silently
switches branches. The inventory lists `var.schema()` calls on a variable,
OpenApiSpex casting calls, and the `items: Module.schema()` sites (the
values whose shape changes). Read `casting-outside-requests.md` before
touching that code. To resolve module references in a schema, use
`JSV.Schema.normalize_collect/2`, which inlines nested JSV schema modules into
`$defs` (recursive schemas included). `JSV.Schema.normalize/2` turns them
into `$ref` strings instead.
