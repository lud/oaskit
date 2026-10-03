# Migrating from OpenApiSpex

Oaskit provides an agent skill that migrates a Phoenix application from OpenApiSpex to
Oaskit and JSV:
[`migrate-openapispex-to-oaskit`](https://github.com/lud/oaskit/tree/main/skills/migrate-openapispex-to-oaskit).

The skill guides a coding agent through the whole migration, from an inventory of the
application to a passing test suite. Scripts do the mechanical rewrites of schemas,
controllers and tests, and the agent handles the remaining cases with the skill's
references. At the end, the agent compares the OpenAPI documents generated before and
after the migration.

The references in the `references` directory of the skill map OpenApiSpex features to
Oaskit and JSV. They are also useful to migrate without an agent.

## Installing the skill

With the [skills](https://github.com/vercel-labs/skills) CLI:

```shell
npx skills add lud/oaskit --skill migrate-openapispex-to-oaskit
```

Or copy the `skills/migrate-openapispex-to-oaskit` directory of this repository to the
skills directory of your agent.

The agent will modify many files, so starting from a clean working tree makes its changes
easier to follow.

## Decisions for your API clients

The migration changes some parts of the API that clients can see. The skill leaves those
choices to you. **Select your answers below, and the example prompt at the end of this
page will follow them.**

### Validation error responses

OpenApiSpex answered validation errors with a 422 status and a list of errors. Oaskit uses
a different body, and the 400, 415 or 422 status depending on the error.

<div class="oaskit-decision">
<label><input type="radio" name="errors" data-prompt="Error responses: use the bridge handler, with the old 422 status." checked> <strong>Bridge handler</strong>: Oaskit's error body plus the former <code>errors</code> list, with the 422 status. Clients keep working and can move to the new format later.</label>
<label><input type="radio" name="errors" data-prompt="Error responses: adopt Oaskit's default error format."> <strong>Oaskit's format</strong>: no error handler to write. Clients that read error bodies must change.</label>
<label><input type="radio" name="errors" data-prompt="Error responses: write an OpenApiSpex-compatible error handler."> <strong>OpenApiSpex format</strong>: a custom error handler renders the former format. For clients that break on the bridge body, for instance when they reject unknown keys.</label>
</div>

### Operation IDs in the OpenAPI document

For operations without an explicit `operation_id`, Oaskit generates different operationIds
than OpenApiSpex. Clients and tools generated from the OpenAPI document use them.

<div class="oaskit-decision">
<label><input type="radio" name="operation_ids" data-prompt="Operation ids: pin them." checked> <strong>Keep them</strong>: the current operationIds are written in each operation.</label>
<label><input type="radio" name="operation_ids" data-prompt="Operation ids: accept Oaskit's generated ids."> <strong>Accept new ones</strong>: generated clients see renamed operations.</label>
</div>

### Schema names in the OpenAPI document

OpenApiSpex named schemas without a title after the last segment of their module (`User`),
Oaskit uses the full module name (`MyApp.Schemas.User`).

<div class="oaskit-decision">
<label><input type="radio" name="components" data-prompt="Component names: keep them (--titles). When several schema modules share a title, keep it on the module the old document used." checked> <strong>Keep them</strong>: a title is added to each schema module that had none.</label>
<label><input type="radio" name="components" data-prompt="Component names: accept Oaskit's names. When several schema modules share a title, keep it on the module the old document used."> <strong>Accept new names</strong>: generated clients see renamed types.</label>
</div>

### String format validation

JSV validates formats that OpenApiSpex ignored, such as `email`, `uri` or `hostname`.

<div class="oaskit-decision">
<label><input type="radio" name="formats" data-prompt="Formats: keep JSV's format validation, and update the tests that expected the error from the action." checked> <strong>Validate them</strong>: invalid values are rejected with a validation error, before the controller action.</label>
<label><input type="radio" name="formats" data-prompt="Formats: do not validate the formats that OpenApiSpex did not check."> <strong>Document them only</strong>: the formats stay in the OpenAPI document and requests are handled as before.</label>
</div>

### Required request bodies

OpenApiSpex request bodies declared as `{description, content_type, schema}`
were optional. The skill rewrites them with the short form of Oaskit
(`request_body: UserSchema`), which makes the body required. With a full
request body declaration, `required` defaults to `false` as in OpenAPI.

<div class="oaskit-decision">
<label><input type="radio" name="request_bodies" data-prompt="Request bodies: required, except where an endpoint accepts an empty body." checked> <strong>Required</strong>: empty bodies get a validation error, except on endpoints that accept them.</label>
<label><input type="radio" name="request_bodies" data-prompt="Request bodies: keep them optional where OpenApiSpex had them optional."> <strong>Optional as before</strong>: Oaskit skips the validation of empty bodies.</label>
</div>

## Example prompt

Add your own instructions to this prompt, for instance how the agent should use git.

```prompt
Migrate this app from OpenApiSpex to Oaskit with the migrate-openapispex-to-oaskit skill, through all its phases.

Decisions for phase 0:
- Error responses: use the bridge handler, with the old 422 status.
- Operation ids: pin them.
- Component names: keep them (--titles). When several schema modules share a title, keep it on the module the old document used.
- Formats: keep JSV's format validation, and update the tests that expected the error from the action.
- Request bodies: required, except where an endpoint accepts an empty body.
```

The skill makes the agent write migration notes outside of the project, in an
`OASKIT_MIGRATION.md` file: the decisions, the test results before the migration, the
tests removed and why, and what changes for API clients. The agent gives you the path of
that file at the end of the migration.
