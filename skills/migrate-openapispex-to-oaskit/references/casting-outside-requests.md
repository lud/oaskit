# Schemas used outside HTTP validation

Some apps use OpenApiSpex schema modules as data contracts outside requests:
casting database records into response structs ("DTOs"), validating
messages, building payloads. The inventory lists the calls that matter:
`OpenApiSpex.cast_value/2,3`, `OpenApiSpex.Cast.*`, and `var.schema()`
called on a variable (code reading schemas at runtime).

Names (JSV schema module, JSV struct module, schema map) are defined in
`SKILL.md`, "Names used in this skill".

## Replacing `OpenApiSpex.cast_value/2`

```elixir
# before
{:ok, value} = OpenApiSpex.cast_value(data, MyApp.Schemas.User.schema())

# after
value = MyApp.JSVCast.cast!(data, MyApp.Schemas.User)
```

```elixir
defmodule MyApp.JSVCast do
  def cast!(data, schema_module) do
    data
    |> JSV.Normalizer.normalize()
    |> JSV.validate!(root(schema_module))
  end

  # Building a JSV root is costly: build once per schema module and keep it.
  defp root(schema_module) do
    key = {__MODULE__, schema_module}

    case :persistent_term.get(key, nil) do
      nil ->
        root = JSV.build!(schema_module, Oaskit.default_jsv_opts())
        :persistent_term.put(key, root)
        root

      root ->
        root
    end
  end
end
```

Build the roots with the same JSV options as your spec modules
(`MyAppWeb.ApiSpec.jsv_opts()` instead of `Oaskit.default_jsv_opts()`) if you
changed them, for example to stop checking some formats (`schemas.md`,
"Formats OpenApiSpex did not check"). Otherwise this code checks what
requests do not. If the casting code lives in a core app that must not
depend on the web layer, put the format validator module in the core app and
use it from both places.

JSV roots can also be built at compile time into a module attribute
(`@root JSV.build!(MyApp.Schemas.User, ...)`). Do that if the set of schemas
is small and known.

`Oaskit.default_jsv_opts()` enables format validation with the formats
Oaskit knows (OpenAPI formats such as `int64`) and `atoms: true` (needed by
`JSV.Schema.Helpers.aprops/2` and `arprops/2` below). With plain JSV, use `JSV.build!(module,
formats: true)`. Without `formats: true`, **JSV ignores `format`**, as the
JSON Schema specification says.

## Input: JSON-shaped data

OpenApiSpex casting accepted atom-keyed maps and atom values. JSV validates JSON-shaped
data: string keys, strings for string values. `JSV.Normalizer.normalize/1`
converts atom keys and atom values (other than `true`, `false`, `nil`) to
strings, recursively.

`JSV.Normalizer.normalize/1` raises `Protocol.UndefinedError` on structs that
do not implement `JSV.Normalizer.Normalize`, including `DateTime`, `Date`,
`Decimal` and Ecto schemas. Either convert them first (`DateTime.to_iso8601/1`,
`Map.from_struct/1`, dropping `__meta__` and `Ecto.Association.NotLoaded`…), or
implement the protocol, here for an Ecto schema:

```elixir
defimpl JSV.Normalizer.Normalize, for: MyApp.Accounts.User do
  def normalize(user), do: user |> Map.from_struct() |> Map.drop([:__meta__])
end
```

Data that contains values already cast by JSV (a struct of a JSV struct
module such as `MyApp.Schemas.User`, embedded in the input) needs the same
implementation for that JSV struct module. If your JSV struct modules share
a `use` macro, implement it once from its `@before_compile` hook (see
`schemas.md`, "Modules that are not objects"):

```elixir
defmacro __before_compile__(env) do
  if Module.defines?(env.module, {:__struct__, 0}) do
    quote do
      require Protocol
      Protocol.derive(JSON.Encoder, __MODULE__)

      defimpl JSV.Normalizer.Normalize do
        def normalize(struct), do: Map.from_struct(struct)
      end
    end
  end
end
```

## Output differences

| Schema | OpenApiSpex output | JSV output |
|---|---|---|
| OpenApiSpex schema module / JSV struct module | struct | struct, **undeclared keys dropped** |
| inline object schema map | map with atom keys | map with **string** keys (undeclared keys kept) |
| `format: "date-time"` string | `DateTime` (OpenApiSpex casting returned it) | the string, unless `cast_formats: true` is passed to `JSV.validate!/3` in `MyApp.JSVCast.cast!/2` |
| invalid data | `{:error, [%OpenApiSpex.Cast.Error{}]}` | `{:error, %JSV.ValidationError{}}` (`JSV.validate!/2` raises it with a readable message) |

Code that reads the output with atom keys (`result.items |> Enum.map(&
&1.name)`, pattern matches like `%{changes: %{status: :rejected}}`) breaks
silently: a pattern stops matching, a value becomes `nil`. Options:

- make the nested object a JSV struct module (see `schemas.md`, "JSV struct
  modules (`defschema`)", the `MyApp.Schemas.Order` example);
- use `JSV.Schema.Helpers.aprops/2` (optional properties) or `arprops/2` (all
  properties required) for an object cast to a map with **atom keys**, without a
  struct. Needs the `atoms: true` build option;
- use the `JSV.defcast/1,2,3` macro to plug your own conversion function
  into a schema (see "Custom cast functions (`defcast`)" in `links.md`);
- or update the reading code to string keys and string values.

Search for code that reads the values returned by `MyApp.JSVCast.cast!/2`
(or your equivalent): pattern matches and `.field` accesses.

## Code that reads schemas at runtime

Code that inspects schemas (`schema.type`, `schema.properties[:data]`,
`schema.items`) worked on `%OpenApiSpex.Schema{}` structs:

- `var.schema()`, where `var` is a variable → `var.json_schema()`;
- `schema.type` raises `KeyError` on a schema map without `type` (plain JSV
  schema modules with a top-level `oneOf`): use `Map.get(schema, :type)`;
- references to other schemas are module **atoms** where OpenApiSpex code had
  inline `%OpenApiSpex.Schema{}` structs when written `Module.schema()`. A branch
  like `if is_atom(schema.items), do: cast_each_item(...), else:
  keep_items_as_is(...)` silently changes behaviour for every schema whose
  items were written `Module.schema()`. In the casting branch, undeclared keys get
  dropped and per-item code (such as a `transform/1` function of the JSV
  schema module given as `items`) starts to run… The inventory report lists
  both sets of sites ("Code using OpenApiSpex schema modules" section):
  `items: Module.schema()` (an inline struct before, an atom now) and
  `items: Module` (an atom before and now). It also counts the properties
  written `Module.schema()`, which change the same way. **The rewrite makes
  the two sets indistinguishable**: keep the inventory report from phase 0.
  To keep the old behaviour, mark the schema modules of one set explicitly
  (usually the smaller one, e.g. a `cast_items?/0` function of your own,
  defined by the shared `use` macro with a default and overridden in those
  modules) and branch on that mark rather than on the shape of the schema;
- `JSV.Schema.schema_module?/1` tells whether an atom is a JSV schema module;
- `JSV.Schema.normalize_collect/2` returns a self-contained schema with nested
  JSV schema modules inlined under `$defs` (recursion included).

## Third-party OpenAPI 3.0 documents

Apps sometimes validate data against an OpenAPI document they do not own,
for example payloads sent to another service, with
`OpenApiSpex.OpenApi.Decode.decode/1` and `OpenApiSpex.Cast.cast/4`. The
inventory lists the `OpenApiSpex.*` modules used for that ("Other OpenApiSpex
modules referenced"). Oaskit only builds OpenAPI 3.1 documents from your spec
modules, so validate with JSV directly.

OpenAPI 3.0 schemas are close to JSON Schema 2020-12, except:

- `nullable: true` → add `"null"` to `type` (and `nil` to `enum`), or
  `anyOf: [%{"type" => "null"}, schema]` without `type`;
- `exclusiveMinimum: true` with `minimum: n` → `exclusiveMinimum: n` (same
  for the maximum);
- keywords next to a `$ref` are ignored in 3.0 and applied in 2020-12;
- `example`, `discriminator`, `xml`… are not validation keywords: JSV
  ignores them.

Convert the decoded JSON once, at compile time, and build a JSV root that
references the component to validate. JSV resolves
`#/components/schemas/...` references against the root document:

```elixir
defmodule MyApp.OpenApi30 do
  @moduledoc """
  Converts OpenAPI 3.0 schemas (decoded JSON, string keys) to JSON Schema
  2020-12 for JSV.
  """

  def to_json_schema(%{"nullable" => true} = schema) do
    schema = Map.delete(schema, "nullable")

    case schema do
      %{"type" => type} ->
        schema
        |> Map.put("type", List.wrap(type) ++ ["null"])
        |> Map.replace_lazy("enum", &(&1 ++ [nil]))
        |> to_json_schema()

      _ ->
        %{"anyOf" => [%{"type" => "null"}, to_json_schema(schema)]}
    end
  end

  def to_json_schema(%{} = schema) do
    schema
    |> Map.delete("nullable")
    |> exclusive("exclusiveMinimum", "minimum")
    |> exclusive("exclusiveMaximum", "maximum")
    |> Map.new(fn {k, v} -> {k, to_json_schema(v)} end)
  end

  def to_json_schema(list) when is_list(list), do: Enum.map(list, &to_json_schema/1)
  def to_json_schema(other), do: other

  defp exclusive(schema, key, bound) do
    case schema do
      %{^key => true, ^bound => n} -> schema |> Map.delete(bound) |> Map.put(key, n)
      %{^key => false} -> Map.delete(schema, key)
      _ -> schema
    end
  end
end
```

```elixir
@external_doc "priv/other_service_openapi.json" |> File.read!() |> JSON.decode!()

@job_root JSV.build!(
            %{
              "$ref" => "#/components/schemas/JobCreateParams",
              "components" => MyApp.OpenApi30.to_json_schema(@external_doc["components"])
            },
            Oaskit.default_jsv_opts()
          )

def validate_job(payload) do
  case JSV.validate(payload, @job_root) do
    {:ok, _} -> :ok
    {:error, verr} -> {:error, JSV.normalize_error(verr, sort: :asc)}
  end
end
```

`Oaskit.default_jsv_opts()` validates formats, including the OpenAPI ones
(`float`, `int32`, `int64`…). Plain `formats: true` only knows the JSON
Schema formats and raises `{:unsupported_format, "float"}` when it builds the
root. To check fewer formats than before (OpenApiSpex checked date,
date-time, uuid and byte), see `schemas.md`, "Formats OpenApiSpex did not
check".

Error messages differ from `OpenApiSpex.Cast.Error.message/1`: each entry of
the normalized error has an `instanceLocation` (`"#/salary"`) and a list of
`errors` with a `message`. To get one string per error (like the list of
`OpenApiSpex.Cast.Error.message/1` strings), flatten it. The `:properties`
and `:items` errors only say that a child failed, the child has its own
entry:

```elixir
defp error_messages(verr) do
  for %{instanceLocation: loc, errors: errors} <- JSV.normalize_error(verr, sort: :asc).details,
      %{kind: kind, message: msg} <- errors,
      kind not in [:properties, :items],
      do: "#{loc}: #{msg}"
end
# ["#: property 'name' is required", "#/salary: value is not of type integer"]
```

Update the tests that match the old messages.

JSV may reject data that `OpenApiSpex.Cast.cast/4` let through (atoms as
strings, formats): run the tests that cover this validation, and add some if
there are none.

## Encoding cast structs to JSON

`JSV.defschema/1` does not derive `JSON.Encoder`/`Jason.Encoder` (OpenApiSpex's
macro derived `Jason.Encoder`). Add `@derive JSON.Encoder` before
`defschema`. If a shared `__using__` macro set `@derive` for every former
OpenApiSpex schema module, move it to an `@before_compile` hook that derives only when the
module defines a struct (see `schemas.md`, "Modules that are not objects").
The same hook can implement `JSV.Normalizer.Normalize` for the struct.
