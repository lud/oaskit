# Documentation links

Full documentation as plain-text indexes for agents (each entry links to a
Markdown page):

- Oaskit: https://oaskit.hexdocs.pm/llms.txt
- JSV: https://jsv.hexdocs.pm/llms.txt

Pages relevant to this migration (Markdown versions, append to the base URL
of each index):

| Topic | Page |
|---|---|
| Oaskit setup, spec module, controllers, tests | https://oaskit.hexdocs.pm/quickstart.md |
| `api_controller/0` in the web module | https://oaskit.hexdocs.pm/web-module.md |
| Security plugs (`:security` option) | https://oaskit.hexdocs.pm/security.md |
| Query/path parameter limitations (casts, type unions, arrays, styles) | https://oaskit.hexdocs.pm/limitations.md |
| `operation/2`, `use_operation/3`, `body_params/1`… | https://oaskit.hexdocs.pm/Oaskit.Controller.md |
| Validation plug options | https://oaskit.hexdocs.pm/Oaskit.Plugs.ValidateRequest.md |
| Error handler behaviour | https://oaskit.hexdocs.pm/Oaskit.ErrorHandler.md |
| Default error handler | https://oaskit.hexdocs.pm/Oaskit.ErrorHandler.Default.md |
| Building the spec at boot (`Oaskit.warmup_spec_cache/2`) | https://oaskit.hexdocs.pm/Oaskit.md |
| Supervision tree child building the spec | https://oaskit.hexdocs.pm/Oaskit.SpecCacheWarmup.md |
| `valid_response/3` | https://oaskit.hexdocs.pm/Oaskit.Test.md |
| `mix openapi.dump` | https://oaskit.hexdocs.pm/Mix.Tasks.Openapi.Dump.md |
| Oaskit changelog | https://oaskit.hexdocs.pm/changelog.md |
| JSV schema modules, `defschema` | https://jsv.hexdocs.pm/defining-schemas.md |
| Schema helpers (`nullable/1`, `aprops/2`, `optional/1`…) | https://jsv.hexdocs.pm/JSV.Schema.Helpers.md |
| Building roots, `formats: true` | https://jsv.hexdocs.pm/build-basics.md |
| Validation, formats and their cast values | https://jsv.hexdocs.pm/validation-basics.md |
| Custom cast functions (`defcast`) | https://jsv.hexdocs.pm/cast-functions.md |
| Error normalization | https://jsv.hexdocs.pm/JSV.ErrorFormatter.md |
| JSV changelog | https://jsv.hexdocs.pm/changelog.md |

The hex packages do not include the guides: read them online. The module
documentation is also in the installed sources under `deps/oaskit/lib` and
`deps/jsv/lib`.
