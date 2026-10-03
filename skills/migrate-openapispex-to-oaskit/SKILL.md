---
name: migrate-openapispex-to-oaskit
description: Step-by-step migration of a Phoenix application from OpenApiSpex (open_api_spex, OpenAPI 3.0) to Oaskit (oaskit, OpenAPI 3.1) and JSV (jsv, JSON Schema 2020-12). Use when asked to replace OpenApiSpex with Oaskit, to port OpenApiSpex schemas to JSV, or to finish/debug such a migration. Includes an inventory script and rewrite scripts.
---

# Migrate a Phoenix app from OpenApiSpex to Oaskit

Use the **latest oaskit release** and the **latest jsv release that oaskit
accepts** (phase 1). This skill was last checked against oaskit 0.16 and jsv
0.25: if the installed versions are newer, read their changelogs
(`references/links.md`) for changes to the facts below. The guide is written from a real
migration of a large app (≈270 schema modules, ≈120 operations, ≈400 schema
assertions in tests) and lists what was mechanical and what needed decisions.

The migration has three layers, done in this order:

1. JSON schemas (OpenApiSpex schema modules and `%OpenApiSpex.Schema{}`
   structs) become schema maps, JSV schema modules and JSV struct modules.
2. Controllers, the router and the spec modules move from OpenApiSpex to
   Oaskit.
3. Tests move from `OpenApiSpex.TestAssertions` to `Oaskit.Test`.

Never skip a gate. Keep the files produced
for the migration (inventory report, old and new OpenAPI documents, the
migration notes `$WORK/OASKIT_MIGRATION.md`) in a work directory outside
the project, written `$WORK` below (your scratch directory, or e.g.
`/tmp/oaskit_migration`).

## Names used in this skill

These libraries reuse the same words for different things. This skill always
uses the names below, and qualifies every function with its module.

| Name in this skill | What it is |
|---|---|
| **OpenApiSpex** | The `open_api_spex` library (`OpenApiSpex.*` modules). The library being removed. |
| **Oaskit** | The `oaskit` library (`Oaskit.*` modules). Request validation, OpenAPI document generation. |
| **JSV** | The `jsv` library (`JSV.*` modules). JSON Schema validation and casting, used by Oaskit. |
| **OpenAPI document** | The JSON document describing the API (`openapi`, `paths`, `components`…), served by a route or written by a mix task. |
| **spec module** | The Elixir module that returns the OpenAPI document from `spec/0`: `@behaviour OpenApiSpex.OpenApi` before, `use Oaskit` after. |
| **schema** | Used alone only when the sentence applies to every kind below (schema map, `%OpenApiSpex.Schema{}`, OpenApiSpex schema module, JSV schema module). |
| **schema map** | A JSON schema written as a plain Elixir map, e.g. `%{type: :string}`. `Module.json_schema()` returns one. |
| **`%OpenApiSpex.Schema{}`** | OpenApiSpex's schema struct, usually written `%Schema{}` after `alias OpenApiSpex.Schema`. |
| **OpenApiSpex schema module** | A module calling `OpenApiSpex.schema/1`. It defines a struct and `schema/0`. |
| **JSV schema module** | Any module exporting `json_schema/0` that returns a JSON schema. JSV and Oaskit accept it wherever a schema is expected. |
| **JSV struct module** | A JSV schema module defined with the `JSV.defschema/1` macro or the module-defining `JSV.defschema/2,3` macro. It also defines a struct, and JSV casts valid data to that struct. |
| **plain JSV schema module** | A JSV schema module that is not a JSV struct module: it only defines `json_schema/0` (arrays, enums, `oneOf`…). |
| **JSV root** | The `JSV.Root` struct returned by `JSV.build!/2` from a schema, given to `JSV.validate/3`. Oaskit builds roots for the whole OpenAPI document. |
| **component** | An entry under `components.schemas` in the OpenAPI document. Its key is the **component name**, taken from the schema `title`. |
| **validation plug** | `OpenApiSpex.Plug.CastAndValidate` before, `Oaskit.Plugs.ValidateRequest` after. |
| **spec provider plug** | `OpenApiSpex.Plug.PutApiSpec` before, `Oaskit.Plugs.SpecProvider` after (attaches the spec module to router pipelines). |
| **error handler** | The module given to `Oaskit.Plugs.ValidateRequest` with `:error_handler`, implementing the `Oaskit.ErrorHandler` behaviour. Replaces OpenApiSpex's `:render_error` plug. |
| **Phoenix params** | What Plug/Phoenix decoded: the `params` argument of a controller action, `conn.body_params`, `conn.path_params`, `conn.query_params`. Oaskit never modifies them. |
| **cast values** | What Oaskit stores in `conn.private.oaskit` after validation, read with `Oaskit.Controller.body_params/1`, `Oaskit.Controller.path_param/3`, `Oaskit.Controller.query_param/3`, `Oaskit.Controller.header_param/3`. |
| **valid_response helper** | A test helper defined in your `ConnCase` that wraps `Oaskit.Test.valid_response/3` (see `references/testing.md`). |
| **inventory report** | The output of `scripts/inventory.exs`. |
| **`Module.schema()`** | A call to `schema/0` on an OpenApiSpex schema module written literally (`MyApp.Schemas.User.schema()`). A call on a variable (`var.schema()`) is code reading schemas at runtime, a different case. |
| **Oaskit shortcut** | The short forms of the `Oaskit.Controller.operation/2` macro: `request_body: User` or `{User, opts}`, `responses: [ok: User]` (`User` being a JSV schema module), for `application/json` content. |

"Schema" alone never means an Ecto schema in this skill.
"Cast" means JSV casting (to structs, formats, atoms) unless written
"OpenApiSpex cast" or "Ecto cast".

## Facts to know before starting

These facts hold for oaskit 0.16 and jsv 0.25. Plan for them:

- The error handler's `handle_error/3` callback **must call
  `Plug.Conn.halt/1`**. `Oaskit.Plugs.ValidateRequest` does not halt after
  calling `handle_error/3`. (OpenApiSpex's validation plug halted after the
  `:render_error` plug.)
- `JSV.defschema/1` with a **map** argument sets no `title`. Oaskit then names
  the component after the full module name (`MyApp.Schemas.User`).
  OpenApiSpex named it after the last module segment (`User`). Add `title:`
  where component names matter (client generators use them).
- Oaskit does not unwrap Plug's `"_json"` key. JSON bodies that are arrays
  need a plug before the validation plug (`references/controllers.md`).
- The same controller action routed twice (`resources` creates PUT and PATCH
  for `:update`) makes Oaskit raise `duplicate operation id` when it builds
  the operations (on the first validated request, not in `mix
  openapi.dump`).
- An operation that declares `security:` gets a **401** from
  `Oaskit.Plugs.ValidateRequest` unless the plug has a `:security` option
  (a security plug, or `false`).
- JSV validates JSON-shaped data: string keys, no atoms as string values.
  OpenApiSpex accepted atom-keyed maps and atom values.

## Phase 0: inventory and decisions

1. Write in the migration notes, `$WORK/OASKIT_MIGRATION.md`, how to get
   the code before the migration back (with git: the current commit). Run
   the test suite with `--seed 0` and write the result there too (number of
   tests, failures, which tests fail). Phase 8 compares with it, with the
   same seed.
2. Run `scripts/inventory.exs` (read-only, needs no dependency) and save
   the inventory report:

   ```sh
   elixir <skill_dir>/scripts/inventory.exs --project . --routes > $WORK/inventory.txt
   ```

   **Read the whole file** (several hundred lines; `head` or `tail` hides
   sections). Keep it until the end: after phase 3, some of its findings
   cannot be found in the code anymore.

   `--routes` runs `mix run` in the project (it must compile) to find
   controller actions routed more than once, and schema titles shared by
   two schema modules of the same router. The inventory report lists counts
   and the `file:line` of every pattern that needs a decision. Each label
   says `(auto)` when a rewrite script handles the case, otherwise which
   file and section of `references/` to read. The section "Other
   OpenApiSpex modules referenced" lists every other use of OpenApiSpex:
   each one must be gone at the end, so find the section of this skill that
   covers it, or plan it as a decision. The report ends with a summary of
   the cases handled by hand, the list of spec modules, and the commands to
   run for each spec module in phases 0, 7 and 9.

3. Dump the current OpenAPI documents **before changing anything**, one file
   per spec module, with the phase 0 commands printed at the end of the
   inventory report:

   ```sh
   mix openapi.spec.json --spec MyAppWeb.ApiSpec --start-app=false --pretty=true $WORK/old_ApiSpec.json
   ```

   The inventory report uses `--start-app=true` when it lists
   `OpenApiSpex.Server.from_endpoint`: building the OpenAPI document then
   starts the whole application (databases, message brokers…). If that
   fails, replace `servers` with a literal in the spec modules for the dump
   only (`servers: [%{url: "..."}]`, reverted right after), and use
   `--start-app=false`.

   You will need these documents in phase 9, and to resolve duplicate
   titles in phase 4. operationIds ending with `" (2)"` in them are actions
   routed twice (`references/controllers.md`, "One controller action,
   several routes"): compare them with the inventory list.

   ```sh
   jq -r '[.paths[][] | objects | .operationId // empty] | .[] | select(endswith(" (2)"))' $WORK/old_ApiSpec.json
   ```

4. Decide what must stay stable for API clients, and write it down in
   the migration notes (add the findings of later phases to them too):
   - **error response format**: adopt Oaskit's format, use a bridge handler
     (Oaskit's format plus the old one in the same body: the default when
     API clients exist, even clients that cannot change now), or an
     OpenApiSpex-compatible handler (`references/errors.md`, "Choosing");
   - **operationIds** in the OpenAPI document (client generators, tools built
     from the document): pin them (phase 2) or accept new ones;
   - **component names**: add titles (`rewrite_lib.exs --titles` in phase 3)
     or accept new names. Titles shared by several schema modules need a
     decision either way (`references/schemas.md`, "Titles and components");
   - **format validation**: JSV validates formats that OpenApiSpex did not
     check (`email`, `uri`…). Keep the new validation or turn it off for
     those formats (`references/schemas.md`, "Formats OpenApiSpex did not
     check");
   - **request bodies** declared with the OpenApiSpex tuple
     `request_body: {description, content_type, User}` were optional
     (`required: false`). The Oaskit shortcut `request_body: User` /
     `{User, opts}` written by `rewrite_lib.exs` defaults to
     `required: true`. Decide per endpoint if needed;
   - **code reading schemas at runtime** (`var.schema()` in the inventory
     report), when it branches on the shape of schemas: the rewrite changes
     `items: Module.schema()` into `items: Module`, which can change what
     that code returns (`references/casting-outside-requests.md`, "Code that
     reads schemas at runtime"). Decide now, while the inventory report still
     tells the two sets of sites apart.

Gate: test result, old OpenAPI documents and inventory report saved,
inventory report read, decisions written in the migration notes.

## Phase 1: dependencies

1. Find the latest oaskit release: `mix hex.info oaskit | grep Config:`
   prints it (e.g. `Config: {:oaskit, "~> 0.16.1"}`).
2. In `mix.exs`, replace `{:open_api_spex, "~> 3.x"}` with that oaskit
   requirement, and with `{:jsv, ">= 0.0.0"}` for now. Declare `:jsv`
   explicitly: the app will call `JSV` directly (`defschema`,
   `JSV.Schema.Helpers`).
3. Fetch, so that Hex picks the latest jsv release that oaskit accepts, and
   read the version it picked:

   ```sh
   mix deps.get
   mix deps.unlock --unused
   grep '"jsv"' mix.lock
   ```

4. Replace `">= 0.0.0"` following the project's convention for
   requirements: `"~> MAJOR.MINOR"` of that version (e.g. `{:jsv, "~> 0.25"}`
   for 0.25.0), or, if the other dependencies are pinned (`== 1.2.3`), pin
   jsv and oaskit to the fetched versions (`grep '"oaskit"' mix.lock`) the
   same way. Then run `mix deps.get` again.

Add `:oaskit` and `:jsv` to `import_deps` in `.formatter.exs`. They export
formatter rules for `operation`, `use_operation`, `parameter`, `tags` and
`defschema`.

Gate: `mix deps.get` succeeds. The app does not compile yet.

## Phase 2: pin operation IDs (if decided in phase 0)

OpenApiSpex's default operationId is `"#{inspect(module)}.#{action}"`.
Oaskit's default is different (`"#{underscore(last module segment)}_#{action}_#{hash}"`,
without the `Controller` suffix). `scripts/pin_operation_ids.exs` adds an
`operation_id:` option, with the OpenApiSpex default, to every `operation`
macro call that has none (the OpenApiSpex macro, or `Oaskit.Controller.operation/2`
if run after phase 3):

```sh
elixir <skill_dir>/scripts/pin_operation_ids.exs --project .          # dry run
elixir <skill_dir>/scripts/pin_operation_ids.exs --project . --write
```

## Phase 3: rewrite schemas and controllers (script)

```sh
elixir <skill_dir>/scripts/rewrite_lib.exs --project . --error-handler MyAppWeb.ApiErrorHandler
elixir <skill_dir>/scripts/rewrite_lib.exs --project . --error-handler MyAppWeb.ApiErrorHandler --write
mix format
```

`rewrite_lib.exs` only applies syntax rewrites. It prints a `REPORT` message
for every place that needs a decision and leaves those places as they are
(one message with the list of places when several places get the same one).
`--error-handler` only inserts the module name in the validation plug. You
implement that module in phase 6 (`references/errors.md`). Omit it to use
Oaskit's default error handler (`Oaskit.ErrorHandler.Default`). `--titles`
adds the title OpenApiSpex used (the last module segment) to untitled schema
modules, if phase 0 decided to keep component names.

What it rewrites, and what each `REPORT` means, is documented in
`references/schemas.md` (schemas) and `references/controllers.md`
(controllers). Read the "Scripts" section below before running any script.

Gate: the script ran, and every `REPORT` message is in your task list (`INFO`
messages need no action).

## Phase 4: finish the schemas

Follow `references/schemas.md` for each `REPORT` message and inventory report
entry. Sections: "nullable", "Modules the script does not convert",
"Formats", "JSV struct modules (`defschema`)" (`required` keys missing from
`properties`), "Mistakes revealed by the stricter tooling", "Titles and
components".

Do not expect `mix compile` to pass before the end of phase 6: spec
modules, routers and controllers still use OpenApiSpex until phases 5 and 6,
and the compiler stops at the first modules that fail.

Gate: `grep -rn "nullable: \|:nullable" lib` only finds `nullable(...)` calls
(`JSV.Schema.Helpers.nullable/1`). JSV ignores a `nullable` key, so a key
left in a schema silently makes `null` invalid.

## Phase 5: spec modules, router, mix aliases

Follow `references/spec-and-router.md`: spec modules, spec provider plugs,
routes serving the OpenAPI document, the `:filter` option of
`Oaskit.Spec.Paths.from_router/2`, mix aliases.

## Phase 6: controllers and the error handler

- Follow `references/controllers.md` for each `REPORT` message: Phoenix params vs
  cast values, `security:`, PUT/PATCH routes, array bodies, controllers that
  had operations but no validation plug, parameters and responses built by
  a function, `conn.private.open_api_spex`.
- Write the error handler following `references/errors.md`.

Then fix compile errors until `mix compile` passes. An error in one schema
module can show up in another one that depends on it, so handle every
`REPORT` message first. Most errors are listed in
`references/troubleshooting.md`.

Gate: `mix compile` passes.

## Phase 7: schemas used outside HTTP validation

If the inventory report listed `OpenApiSpex.cast_value`/`OpenApiSpex.Cast`
calls, or `var.schema()` calls on a variable (code reading schemas at
runtime), follow `references/casting-outside-requests.md`.

Gate: `mix compile --warnings-as-errors` passes, and Oaskit builds every
spec module (operations and JSV roots), as the validation plug does on the
first validated request:

```sh
mix run --no-start -e 'for m <- [MyAppWeb.ApiSpec], do: Oaskit.build_spec!(m, cache: false, responses: true)'
```

List every spec module (the inventory report prints this command with all
of them). This is the check for duplicate operationIds
and unknown formats. `mix openapi.dump` is not: it only writes the OpenAPI
document and validates it against the OpenAPI 3.1 meta-schema.
(`Oaskit.build_spec!/2` is undocumented as of Oaskit 0.16. `responses: true`
also builds the response schemas used by `Oaskit.Test.valid_response/3`.)

## Phase 8: tests

1. Add the valid_response helper to `ConnCase` (`references/testing.md`).
2. Run `scripts/rewrite_tests.exs`, with `--wrapper NAME` for each test
   helper wrapping `assert_schema` listed by the inventory report
   (`references/testing.md`, "Helpers wrapping assert_schema"):

   ```sh
   elixir <skill_dir>/scripts/rewrite_tests.exs --project .          # dry run
   elixir <skill_dir>/scripts/rewrite_tests.exs --project . --write
   mix format
   ```

3. Migrate the `REPORT` messages by hand. The script removes the aliases and
   `response =` bindings that only served the removed calls: fix what the
   compiler still reports as unused.
4. Run the test suite with `--seed 0`, then fix failures with the failure table in
   `references/testing.md`. The valid_response helper is stricter than
   `OpenApiSpex.TestAssertions.assert_schema/3`, so expect it to reveal mistakes in the OpenAPI
   document. Tests that failed in phase 0 are not the migration's. For a
   new failure outside the API layer, check whether it also happens before
   the migration first (`references/testing.md`, "Slow or flaky suites").

Gate: the test suite passes, with the number of tests of phase 0, minus
the tests that only tested OpenApiSpex itself (e.g. tests walking
`%OpenApiSpex.Schema{}` structs) if you removed them: list them in the
migration notes.

## Phase 9: compare the OpenAPI documents

For each spec module (the inventory report prints the `mix openapi.dump`
commands):

```sh
mix openapi.dump MyAppWeb.ApiSpec -o $WORK/new_ApiSpec.json
<skill_dir>/scripts/spec_diff.sh $WORK/old_ApiSpec.json $WORK/new_ApiSpec.json
<skill_dir>/scripts/spec_diff.sh --deep $WORK/old_ApiSpec.json $WORK/new_ApiSpec.json
```

Explain every difference: servers, operations, details of the operations
(response statuses, `requestBody.required`, parameters, security), and
component names. `--deep` also compares the body of each component and the
schema of each parameter, after normalizing the old document (`nullable`,
`example`, OpenApiSpex extensions): it shows the schemas changed by hand. Expected ones are
listed in `references/spec-and-router.md` ("Expected differences").
`mix openapi.dump` also validates the document against the OpenAPI 3.1
meta-schema and prints warnings. It does not build operations (see the
phase 7 gate).

## Phase 10: final checks

- Run the project's CI checks (format, credo, dialyzer, sobelow… whatever
  the project uses).
- If the project keeps dumped OpenAPI documents in its sources, regenerate
  them with the new mix alias (`references/spec-and-router.md`, "Mix tasks
  and aliases").
- `grep -rn -i -e openapispex -e open_api_spex -e swagger --exclude-dir={_build,deps,.git,.claude,node_modules} .`
  must only find documentation to update. Update it, or list it for the user.
  Comments copied from the examples of this skill (error handler, formats
  module) mention OpenApiSpex on purpose.
- Check the decisions from phase 0 against the final OpenAPI documents and
  error responses.
- Give the migration notes to the user: their path, and a summary of the
  decisions and of what changes for API clients. They can serve as the pull
  request description.

## Scripts

All scripts are in `scripts/` and run with `elixir`. They are standalone
(`Mix.install`) and never add a dependency to the project.

| Script | Writes? | Purpose |
|---|---|---|
| `inventory.exs --project P [--routes]` | never | Counts and `file:line` of every pattern that matters, a summary of the cases handled by hand, and the commands to run per spec module. `--routes`: actions on several routes and duplicate titles per router. |
| `pin_operation_ids.exs --project P [--write] [paths]` | with `--write` | Writes OpenApiSpex's default operationIds explicitly. Default path: `lib`. |
| `rewrite_lib.exs --project P [--error-handler M] [--titles] [--write] [paths]` | with `--write` | Syntax rewrites of schemas and controllers. `--titles`: titles for untitled schema modules. Default path: `lib`. |
| `rewrite_tests.exs --project P [--helper NAME] [--wrapper NAME]... [--write] [paths]` | with `--write` | `OpenApiSpex.TestAssertions.assert_schema/3` → the valid_response helper, then removes the bindings and aliases only used by the removed calls. `--wrapper`: calls of a project helper wrapping `assert_schema` → the valid_response helper. Default path: `test`. |
| `spec_diff.sh [--deep] OLD.json NEW.json` | never | Diff of servers, operations, operation details (statuses, `requestBody.required`, parameters, security) and component names (needs `jq`). `--deep`: also component bodies and parameter schemas, normalized. |

- `P` is the project directory. `paths` are files or directories relative to
  `P`. `--error-handler M`: the error handler module written in
  `plug Oaskit.Plugs.ValidateRequest, error_handler: M`. `--helper NAME`: the
  name of the valid_response helper function (default `valid_response`).
  `--wrapper NAME`: a test helper of the project wrapping `assert_schema`,
  called as `NAME(conn, status, ...)` (repeat the option for several).
- The three rewrite scripts (`pin_operation_ids.exs`, `rewrite_lib.exs`,
  `rewrite_tests.exs`) are dry runs by default: they print `CHANGED file`,
  `REPORT file:line message` (something to decide or do by hand) and
  `INFO file:line message` (done, nothing to do), after the `CHANGED` lines.
  A message given for several places is printed once as
  `REPORT (N places) message`, followed by one `REPORT   file:line` line
  per place (so `grep REPORT` keeps them). Pass `--write` to apply.
- They read formatter options from the project's `.formatter.exs` and from
  `deps/<dep>/.formatter.exs` for each `import_deps` entry, so run
  `mix deps.get` first.
- They are idempotent: running them again on rewritten files changes nothing.
- Each rule is documented in the references. The scripts never apply a
  rewrite that changes runtime meaning without a `REPORT`, except
  `Module.schema()` → `Module` (a module reference instead of an inline copy),
  which matters only for code reading schemas at runtime
  (`references/casting-outside-requests.md`, "Code that reads schemas at
  runtime").
- Review the changes of each script before running the next one.

## References

- `references/schemas.md`: OpenApiSpex schemas → JSV schemas.
- `references/controllers.md`: operations, the validation plug, Phoenix
  params vs cast values, security, routes, array bodies, operationIds.
- `references/spec-and-router.md`: spec modules, router, serving the
  OpenAPI document, mix tasks, expected document differences.
- `references/errors.md`: error handlers (bridge handler and
  OpenApiSpex-compatible handler examples).
- `references/testing.md`: the valid_response helper and typical failures.
- `references/casting-outside-requests.md`: casting data with schema modules
  outside requests (for example turning database records into response
  structs, sometimes called DTOs).
- `references/troubleshooting.md`: symptom → cause → fix.
- `references/links.md`: Oaskit and JSV documentation (llms.txt indexes and
  guide pages).
