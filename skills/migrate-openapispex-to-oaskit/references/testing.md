# Tests: OpenApiSpex.TestAssertions → Oaskit.Test

Names (valid_response helper, spec provider plug, validation plug) are
defined in `SKILL.md`, "Names used in this skill".

## The valid_response helper

`Oaskit.Test.valid_response(spec_module, conn, status)` checks the response
status, content type, headers and body against the response that the
**operation which served the request** declares for that status. It returns
the decoded JSON body. It raises when the status is not declared, when the
body does not match, or when the request did not go through
`Oaskit.Plugs.ValidateRequest`.

Define the valid_response helper in the `MyAppWeb.ConnCase` module body (not
inside its `using` block). It finds the spec module from the conn with
`Oaskit.Plugs.SpecProvider.fetch_spec_module!/1` (the spec provider plug
stores it in the conn), so one helper works for all spec modules:

```elixir
# test/support/conn_case.ex
alias Oaskit.Plugs.SpecProvider

def valid_response(conn, status) do
  conn
  |> SpecProvider.fetch_spec_module!()
  |> Oaskit.Test.valid_response(conn, status)
end
```

`ConnCase` usually has `import MyAppWeb.ConnCase` in its `using` block, which
makes the helper available in tests. Otherwise import it there.

Oaskit builds the response schemas of a spec module on the first call of the
valid_response helper, and the tests that call it meanwhile wait for that
build while holding their database connection. Build them before the suite
starts, in `test/test_helper.exs` after `ExUnit.start()`, with one line per
spec module:

```elixir
:ok = Oaskit.warmup_spec_cache(MyAppWeb.ApiSpec, responses: true)
```

## Rewriting assert_schema/3

OpenApiSpex tests usually look like:

```elixir
response = conn |> get(~p"/api/users/#{id}") |> json_response(200)
assert %{"name" => "Alice"} = response
assert_schema(response, "User", MyAppWeb.ApiSpec.spec())
```

`scripts/rewrite_tests.exs` turns them into:

```elixir
response = conn |> get(~p"/api/users/#{id}") |> valid_response(200)
assert %{"name" => "Alice"} = response
```

It also handles `Enum.each(list, &assert_schema(&1, "Item", spec))`, where
`list` comes from `json_response/2`, and removes `import
OpenApiSpex.TestAssertions`. It drops the `response =` binding when
`response` is not used after the removed call, and removes the `alias` of
modules only used by the removed calls (usually the spec module). A comment placed just above a removed
`assert_schema` call is removed with it (an `INFO` line quotes it). It reports the `assert_schema` calls it cannot
pair with a `json_response` assignment in the same block. Typically the
response comes from a `setup` block: replace `json_response(status)` there by
hand with `valid_response(status)`, or keep `json_response/2` for the cases
listed below.

After the script, fix what the compiler still reports as unused (in the
places migrated by hand).

## Helpers wrapping assert_schema

Projects often call `OpenApiSpex.TestAssertions.assert_schema/3` through
their own helper, e.g. in `ConnCase`:

```elixir
def valid_json_response(conn, status, schema_title) do
  data = Phoenix.ConnTest.json_response(conn, status)
  OpenApiSpex.TestAssertions.assert_schema(data, schema_title, conn.private.open_api_spex.spec_module.spec())
  data
end
```

The inventory lists them ("assert_schema inside a helper function") with
their calls. Give each one to `rewrite_tests.exs` with `--wrapper`:

```sh
elixir <skill_dir>/scripts/rewrite_tests.exs --project . --wrapper valid_json_response --write
```

Calls `valid_json_response(conn, 200, "User")` and `conn |>
valid_json_response(200, "User")` become `valid_response(conn, 200)` and
`conn |> valid_response(200)`: the schema title is dropped. Calls with more
arguments (`valid_json_response(conn, 404, "NotFound", api_spec: Spec)`) are
left as is and reported: an explicit spec usually means the conn did not go
through the validation plug (a controller's `call/2` tested directly). Use
the third choice of "When to keep `json_response/2`" for them. The script
reports the helper definition: delete it once the tests compile.

The script also points out (`INFO`) the rewritten checks of 401 and 403
responses: when a router pipeline plug sends them, the valid_response helper
raises "the connection was not validated".

`OpenApiSpex.TestAssertions.assert_raw_schema/2,3` and
`OpenApiSpex.TestAssertions.assert_operation_response/1,2` have no automatic
rewrite. Use the valid_response helper, or validate a value directly with
`JSV.validate/2` and a JSV root built from the JSV schema module
(`JSV.build!(MyApp.Schemas.User, Oaskit.default_jsv_opts())`).

## When to keep `json_response/2`

The valid_response helper needs the request to reach an action with an
operation:

- responses sent by plugs that run before the controller (router pipeline
  plugs answering 401/404, rate limiting…): no operation applies;
- controllers without the validation plug (see `controllers.md`);
- actions with `operation :action, false`.

In these cases there is a third choice: keep `json_response/2` and validate
the body against a JSV schema module (e.g. a fallback controller tested by
calling `call/2` directly):

```elixir
# test/support/conn_case.ex
def valid_schema_response(conn, status, schema_module) do
  body = Phoenix.ConnTest.json_response(conn, status)
  root = JSV.build!(schema_module, Oaskit.default_jsv_opts())

  case JSV.validate(body, root, cast: false) do
    {:ok, _} -> body
    {:error, err} -> ExUnit.Assertions.flunk(Exception.message(err))
  end
end
```

## Typical failures after the switch

The valid_response helper is stricter than
`OpenApiSpex.TestAssertions.assert_schema/3`, which checked the body against
**any** component chosen by title, whatever the operation declared. Failures usually reveal mistakes in the OpenAPI
document. Fix the document rather than the test.

| Failure | Cause | Fix |
|---|---|---|
| `could not find response definition for operation "X" with status 422` | The operation does not declare that status. Common: validation errors declared as 400 while the API answers 422 | Declare the status with your error response schema (`422 => {MyAppWeb.ErrorResponse, description: "..."}`, or `Oaskit.ErrorHandler.Default.error_response_schema()` with the default error handler) |
| `could not find response definition ... with status 201` (or 200) | The declared success status is not the one the action sends | Fix the declared status (the code is what clients get today) |
| `invalid response ... value is not of type object` with a list in "Response data" | The operation declares an item schema but returns a list (old tests validated each item with `Enum.each`) | Declare `{%{type: :array, items: Item}, description: "..."}` |
| `the connection was not validated by Oaskit.Plugs.ValidateRequest` | Response sent before the controller, controller without the validation plug, or `operation :x, false` | See "When to keep `json_response/2`" |
| `expected response with status 201, got: 422` with `invalid_type` on a field the test sets to an atom | The test sends `%{origin: :sourcing}`. `Phoenix.ConnTest` passes map params to the app **without JSON encoding**, so the atom reaches `Oaskit.Plugs.ValidateRequest`. OpenApiSpex's string cast accepted atoms, JSV does not (an atom is not a JSON string) | Send strings in tests (`"sourcing"`, `to_string(record.status)`). Watch for values copied from factories or records into params: Ecto enum fields are atoms (`scoring_type: criteria.scoring_type`). Real JSON requests are not affected |
| A declared but absent key now appears as `null` in a response | A schema that OpenApiSpex never applied (e.g. `nullable` without `type`) is now applied and casts to a struct | Expected. Update the test, or keep the schema typeless (see `schemas.md`, "nullable") |
| A test expecting an error from the action (e.g. a changeset error `"has invalid format"` on an email) gets the error handler's body | JSV validates formats that OpenApiSpex did not check (`email`, `uri`…), so the validation plug rejects the request first | The phase 0 decision: update the test, or stop checking those formats (`schemas.md`, "Formats OpenApiSpex did not check") |
| `Protocol.UndefinedError: protocol JSV.Normalizer.Normalize not implemented for MyApp.Schemas.X (a struct)` from code casting outside requests | The data given to `JSV.Normalizer.normalize/1` contains structs already cast by JSV | Implement the protocol for JSV struct modules (`casting-outside-requests.md`, "Input: JSON-shaped data") |
| A response value differs or is missing, **without any error** | Code matching atom keys or atom values on data cast by JSV stops matching silently (inline object schema maps are cast with string keys) | `casting-outside-requests.md`, "Output differences": search the code that consumes cast values |
| `JSV.ValidationError` raised by your casting code (not by the valid_response helper) | The schema did not match the real data (e.g. an `enum` missing a value) and is now enforced: OpenApiSpex never applied it (a keyword used as a property name, no `type`…) | Fix the schema to match the data |
| Error list length/order differs | JSV error structure differs from OpenApiSpex's | See `errors.md` |
| 400 with `value is not of type integer or null` on a query parameter (`?page=1`) | The parameter schema is a type union (`nullable: true` converted). Oaskit only casts parameter strings for single-type schemas | Remove `:null` from the parameter type (`controllers.md`, "Parameters"). Check the parameters built by a project function: `rewrite_lib.exs` only converts the lists with both `in:` and `schema:` |
| 400 with `missing parameter id in path` | OpenApiSpex parameter with `name:` different from its key (`id: [in: :path, name: :run_id]`). Oaskit uses the key | Rename the key (`controllers.md`, "Parameters") |
| A test requesting the Swagger UI route fails | Oaskit has no Swagger UI | Test the Redoc route instead, or remove the test (`spec-and-router.md`, "Router") |
| 401 on endpoints whose operations declare `security:` | Validation plug without a `:security` option | `security: false` or a security plug (see `controllers.md`) |

## Slow or flaky suites

The suite is slower after the switch: responses are validated too.

`DBConnection.ConnectionError ... queue_timeout` in the sandbox checkout,
in different tests on each run, means tests wait too long for a database
connection. Check that `test/test_helper.exs` builds every spec module
(see "The valid_response helper") before debugging anything else.

If tests still fail intermittently with random seeds, run the same seeds on
the code before the migration before blaming the migration.

The same holds for a failure outside the API layer (a test that does not
call an endpoint, or fails in a module the migration did not touch). Async
tests that share global state (the application environment, named
processes) fail on some seeds only, and `--seed 0` can be one of them. The
same seed does not give the same order once tests were added or removed, so
compare failures, not seeds:

1. get a copy of the code before the migration (written in the migration
   notes in phase 0, e.g. a `git worktree` of that commit). It needs its own
   `deps` and `_build`: copy them or fetch and compile;
2. run the failing test files there with several seeds
   (`for s in 1 2 3 4 5 6; do mix test --seed $s test/path_test.exs; done`)
   until the same failures appear;
3. if they appear, they are not the migration's: write them in the
   migration notes.
