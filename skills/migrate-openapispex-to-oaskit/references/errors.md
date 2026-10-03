# Error handlers

Names (validation plug, error handler) are defined in `SKILL.md`, "Names used
in this skill".

## The `Oaskit.ErrorHandler` contract

```elixir
plug Oaskit.Plugs.ValidateRequest, error_handler: MyAppWeb.ApiErrorHandler
# or
plug Oaskit.Plugs.ValidateRequest, error_handler: {MyAppWeb.ApiErrorHandler, arg}
```

The error handler implements the `Oaskit.ErrorHandler.handle_error/3`
callback, `handle_error(conn, reason, third_argument)`:

- must send the response **and return a halted conn** (`Plug.Conn.halt/1`).
  `Oaskit.Plugs.ValidateRequest` returns the handler's conn as is. A conn that
  is sent but not halted continues to the action, which then fails with
  `Plug.Conn.AlreadySentError`. OpenApiSpex's validation plug halted after the
  `:render_error` plug, so ported renderers usually lack the call.
- `third_argument` is, with `error_handler: Module`, the keyword list of all
  options given to the validation plug (unknown options are kept, so you can
  pass your own); with `error_handler: {Module, arg}`, `arg` as is.
- `reason` is one of:
  - `%Oaskit.Errors.InvalidBodyError{value: body, validation_error: %JSV.ValidationError{}}`.
    `JSV.ValidationError` is the exception returned by JSV validation. It
    contains a list of `JSV.Validator.Error` structs (an opaque type): read it
    with `JSV.normalize_error/2`, not field by field.
  - `%Oaskit.Errors.UnsupportedMediaTypeError{media_type: content_type}`
  - `{:parameters_errors, [%Oaskit.Errors.InvalidParameterError{name:, in:, validation_error:} | %Oaskit.Errors.MissingParameterError{name:, in:}]}`
- Parameters are validated first. If a parameter is invalid, the body is not
  validated.

## What changes for API clients

OpenApiSpex's built-in `:render_error` plugs, `OpenApiSpex.Plug.JsonRenderError`
(v1, the default) and `OpenApiSpex.Plug.JsonRenderErrorV2` (with
`json_render_error_v2: true`), answered 422 for every error with:

```json
{"errors": [{"title": "Invalid value", "source": {"pointer": "/items/0/sku"}, "detail": "Missing field: sku"}]}
```

(`"message"` instead of `"detail"` for `OpenApiSpex.Plug.JsonRenderError`.)
Apps often had their own `:render_error` plug with a similar list.

Oaskit's default error handler, `Oaskit.ErrorHandler.Default`:

- status: 400 for parameters, 415 for an unsupported content type, 422 for an
  invalid body;
- JSON body: `{"error": {"message": "Unprocessable Entity", "kind": "unprocessable_content", "operation_id": "...", "in": "body", "validation_error": {...normalized JSV error...}}}`
  (parameters: `"in": "parameters"` and a `"parameters_errors"` list);
- an HTML page instead of JSON when the request `accept` header contains
  `html`, unless the validation plug has `html_errors: false`.
  `rewrite_lib.exs` writes `html_errors: false` (OpenApiSpex always answered
  JSON). The validation plug gives its options to the error handler, so
  handlers that call `Oaskit.ErrorHandler.Default.handle_error/3` (the bridge
  handler below) follow it too;
- `Oaskit.ErrorHandler.Default.error_response_schema/0` returns a JSV schema
  module describing that JSON body, to declare error responses in operations
  (e.g. `responses: [ok: User, default: Oaskit.ErrorHandler.Default.error_response_schema()]`).

## Choosing

1. **Adopt Oaskit's format**: no handler to write. Clients must change.
2. **Bridge handler**: Oaskit's format plus the old `"errors"` list in the same body.
   Clients keep working **without any change** (same status, the old list
   is still there), including clients that cannot be updated now, and move
   to the new keys when ready. Remove the legacy key
   afterwards. **The default when clients exist.**
3. **OpenApiSpex-compatible handler** (keep the old format): a handler rendering exactly the OpenApiSpex
   format. Only for clients that break on the bridge body (they reject
   unknown keys, or compare whole bodies). The cost is a custom error
   layer to maintain, and an API that keeps the old format for good.

The error messages are JSV's in options 2 and 3 (`"value is not of type
string"`), not OpenApiSpex's: no option keeps them.

Options 2 and 3 need to turn JSV errors into OpenApiSpex-like entries. The
examples use Elixir's `JSON` module (Elixir 1.18+): use the project's JSON
library instead (`Jason`, set in `:json_library`) if it uses one. The
three modules below (`MyAppWeb.LegacyApiErrors`, `MyAppWeb.BridgeErrorHandler`,
`MyAppWeb.LegacyErrorHandler`) were tested with oaskit 0.16 / jsv 0.25 (check the changelogs for newer versions). Rename
them and adapt the rendered keys to your former format.

## Translating JSV errors into OpenApiSpex-like entries

`MyAppWeb.LegacyApiErrors.from_reason/1` takes the `reason` given to
`handle_error/3` and returns one entry per invalid value:
`%{path: [...], code: "missing_field", message: "..."}`. Differences to handle
(all handled below):

- JSV reports `required` and `additionalProperties` on the **parent** object
  (`"#/items/0"`), with the property names only in the message (`property
  'sku' is required`). OpenApiSpex reported one error per property, with the
  property in the path. The names are not available as data (JSV issue #144),
  so they are parsed from the message.
- JSV reports every failing keyword of a value (`type` and `enum`).
  OpenApiSpex stopped at the first one.
- OpenApiSpex checked the required properties of an object before casting
  its properties: an object with missing properties only got the
  `missing_field` errors, nothing for its present properties. JSV reports
  both. The errors located strictly under an object that has a `required`
  error are dropped.
- OpenApiSpex reported `null_value` (not `invalid_type`) for a `null` on a
  non-nullable value. JSV errors do not carry the value, so it is read from
  the validated value (the body, or the parameter value) at the error's
  instance location.
- For `oneOf`/`anyOf`, JSV nests the errors of each branch under `details`.
  OpenApiSpex reported the combinator error and the branch errors.
- Use `JSV.normalize_error/2` (public API) rather than the fields of
  `JSV.Validator.Error`, which is an opaque type.
- Messages are JSV's (`property 'sku' is required`), not OpenApiSpex's
  (`Missing field: sku`). The error codes below (`missing_field`,
  `invalid_enum`…) are OpenApiSpex's (the `reason` field of
  `OpenApiSpex.Cast.Error`), for clients that match on them.

```elixir
defmodule MyAppWeb.LegacyApiErrors do
  @moduledoc """
  Translates Oaskit validation error reasons into one entry per invalid value,
  with OpenApiSpex-like error codes: `%{path: ["items", 0, "name"], code:
  "missing_field", message: "..."}`.
  """

  alias Oaskit.Errors.InvalidBodyError
  alias Oaskit.Errors.InvalidParameterError
  alias Oaskit.Errors.MissingParameterError
  alias Oaskit.Errors.UnsupportedMediaTypeError

  def from_reason(%InvalidBodyError{value: value, validation_error: verr}),
    do: from_validation_error(verr, value, [])

  def from_reason(%UnsupportedMediaTypeError{media_type: media_type}) do
    [%{path: [], code: "invalid_header", message: "unsupported content-type #{media_type}"}]
  end

  def from_reason({:parameters_errors, errors}) do
    Enum.flat_map(errors, fn
      %MissingParameterError{name: name} ->
        [%{path: [name], code: "missing_field", message: "missing parameter #{name}"}]

      %InvalidParameterError{name: name, value: value, validation_error: verr} ->
        from_validation_error(verr, value, [name])
    end)
  end

  def to_pointer(path), do: "/" <> Enum.map_join(path, "/", &to_string/1)

  defp from_validation_error(verr, value, prefix) do
    errors =
      verr
      |> JSV.normalize_error(min_error_level: JSV.ErrorFormatter.level_cause(), sort: :asc)
      |> Map.fetch!(:details)
      |> Enum.flat_map(&unit_errors/1)

    # OpenApiSpex reported nothing under an object with missing properties.
    incomplete_objects = for {path, %{kind: :required}} <- errors, do: path

    errors
    |> Enum.reject(fn {path, _} -> Enum.any?(incomplete_objects, &strict_prefix?(&1, path)) end)
    |> Enum.flat_map(fn {path, error} -> entries(path, error, value) end)
    # OpenApiSpex stopped at the first error of a value, JSV reports all of
    # them (e.g. both `type` and `enum`).
    |> Enum.uniq_by(& &1.path)
    |> Enum.map(&%{&1 | path: prefix ++ &1.path})
  end

  defp strict_prefix?(prefix, path),
    do: length(path) > length(prefix) and List.starts_with?(path, prefix)

  # Keyword errors of combinators (oneOf, anyOf…) carry the errors of each
  # branch in `details`. OpenApiSpex reported the combinator error and the
  # branch errors.
  defp unit_errors(%{instanceLocation: location} = unit) do
    path = parse_pointer(location)

    unit
    |> Map.get(:errors, [])
    |> Enum.flat_map(fn
      %{details: details} = error -> [{path, error} | Enum.flat_map(details, &unit_errors/1)]
      error -> [{path, error}]
    end)
  end

  defp parse_pointer("#" <> pointer) do
    pointer
    |> String.split("/", trim: true)
    |> Enum.map(fn segment ->
      case Integer.parse(segment) do
        {index, ""} -> index
        _ -> segment
      end
    end)
  end

  # JSV reports `required` and `additionalProperties` on the parent object,
  # with the property names only in the message. OpenApiSpex reported one
  # error per property, with the property in the path.
  defp entries(path, %{kind: kind, message: message}, _value)
       when kind in [:required, :additionalProperties] do
    ~r/'([^']+)'/
    |> Regex.scan(message, capture: :all_but_first)
    |> Enum.map(fn [prop] -> %{path: path ++ [prop], code: code(kind), message: message} end)
  end

  # JSV errors do not carry the invalid value.
  defp entries(path, %{kind: :type, message: message}, value) do
    code = if value_at(value, path) == nil, do: "null_value", else: "invalid_type"
    [%{path: path, code: code, message: message}]
  end

  defp entries(path, %{kind: kind, message: message}, _value) do
    [%{path: path, code: code(kind), message: message}]
  end

  defp value_at(value, []), do: value
  defp value_at(map, [key | rest]) when is_map(map), do: value_at(Map.get(map, key), rest)

  defp value_at(list, [index | rest]) when is_list(list) and is_integer(index),
    do: value_at(Enum.at(list, index), rest)

  defp value_at(_, _), do: :not_found

  defp code(:required), do: "missing_field"
  defp code(:additionalProperties), do: "unexpected_field"
  defp code(:enum), do: "invalid_enum"
  defp code(:const), do: "invalid_enum"
  defp code(:format), do: "invalid_format"
  defp code(:pattern), do: "invalid_format"
  defp code(:maxLength), do: "max_length"
  defp code(:minLength), do: "min_length"
  defp code(:maxItems), do: "max_items"
  defp code(:minItems), do: "min_items"
  defp code(:minimum), do: "minimum"
  defp code(:maximum), do: "maximum"
  defp code(:exclusiveMinimum), do: "exclusive_min"
  defp code(:exclusiveMaximum), do: "exclusive_max"
  defp code(:oneOf), do: "one_of"
  defp code(:anyOf), do: "any_of"
  defp code(kind), do: Macro.underscore(to_string(kind))
end
```

## Option 2: bridge handler

The default error handler sends the response itself, so the legacy key is
added with `Plug.Conn.register_before_send/2`, whose callback runs just before
the response is sent.
The module below keeps OpenApiSpex's status, 422 for every error (first
line of `add_legacy_errors/2`). To send Oaskit's statuses (400 for
parameters, 415 for an unsupported content type, 422 for the body), remove
that line.

```elixir
defmodule MyAppWeb.BridgeErrorHandler do
  @moduledoc """
  Renders Oaskit's default error response (`"error"` key) with the legacy
  422 status, and adds the legacy `"errors"` list next to it, so clients can
  move to the new format at their own pace.
  """
  @behaviour Oaskit.ErrorHandler

  alias MyAppWeb.LegacyApiErrors
  alias Plug.Conn

  @impl true
  def handle_error(conn, reason, opts) do
    conn
    |> Conn.register_before_send(&add_legacy_errors(&1, reason))
    |> Oaskit.ErrorHandler.Default.handle_error(reason, opts)
  end

  # The default handler renders HTML when the request accepts HTML. Only JSON
  # responses are patched.
  defp add_legacy_errors(conn, reason) do
    conn = %{conn | status: 422}

    case Conn.get_resp_header(conn, "content-type") do
      ["application/json" <> _] ->
        legacy =
          reason
          |> LegacyApiErrors.from_reason()
          |> Enum.map(fn entry ->
            %{
              title: "Invalid value",
              source: %{pointer: LegacyApiErrors.to_pointer(entry.path)},
              detail: entry.message
            }
          end)

        body = conn.resp_body |> IO.iodata_to_binary() |> JSON.decode!()
        %{conn | resp_body: JSON.encode!(Map.put(body, "errors", legacy))}

      _ ->
        conn
    end
  end
end
```

## Option 3: OpenApiSpex-compatible handler

```elixir
defmodule MyAppWeb.LegacyErrorHandler do
  @moduledoc """
  Renders validation errors in the format of OpenApiSpex's JsonRenderErrorV2
  (`plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true`), with
  a 422 status for every error.
  """
  @behaviour Oaskit.ErrorHandler

  alias MyAppWeb.LegacyApiErrors
  alias Plug.Conn

  @impl true
  def handle_error(conn, reason, _opts) do
    errors =
      reason
      |> LegacyApiErrors.from_reason()
      |> Enum.map(fn entry ->
        %{
          title: "Invalid value",
          source: %{pointer: LegacyApiErrors.to_pointer(entry.path)},
          detail: entry.message
        }
      end)

    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(422, JSON.encode!(%{errors: errors}))
    # Oaskit.Plugs.ValidateRequest does not halt for you.
    |> Conn.halt()
  end
end
```

A custom format such as `%{field: "items.sku", message: "missing_field"}`
(path segments joined with dots, array indexes dropped) is a few lines from
the same entries:

```elixir
%{
  field: entry.path |> Enum.reject(&is_integer/1) |> Enum.join("."),
  message: entry.code
}
```

To port a former `:render_error` plug, read what it took from each
`OpenApiSpex.Cast.Error`:

- `error.reason` → `entry.code` (the same strings: `missing_field`,
  `invalid_type`…);
- `error.path` → `entry.path`. OpenApiSpex used atoms for property names,
  `entry.path` uses strings (and integers for array indexes): a plug that
  kept the property names with `Enum.filter(error.path, &is_atom/1)` now
  uses `Enum.reject(entry.path, &is_integer/1)`.

Then build the same body from the entries, nested keys included (e.g.
`%{field: "a.b", value: %{message: entry.code}}`).

## Tests that assert error bodies

Tests comparing full error lists with `==` depend on the order and number of
entries. `MyAppWeb.LegacyApiErrors` sorts by instance location (`sort: :asc`),
keeps one entry per path, and drops the errors under an object with missing
properties, as OpenApiSpex did. Check tests that expected a combinator error
(`"one_of"`) together with the branch errors.
