Release: 3.2.0, published 2025-09-19, announced 2025-09-23. Compatibility policy: major.minor designates the feature set; almost all valid 3.1 documents are valid 3.2 documents (only new deprecations and one tightened constraint noted below). Comparison baseline: 3.1.1.

Sources
- Spec: https://spec.openapis.org/oas/v3.2.0.html
- Release notes: https://github.com/OAI/OpenAPI-Specification/releases/tag/3.2.0
- Announcement: https://www.openapis.org/blog/2025/09/23/announcing-openapi-v3-2
- Direct diff of spec sources: https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.1.1.md vs https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.2.0.md (field-anchor and text diff performed locally)
- Meta-schema: https://spec.openapis.org/oas/3.2/schema/2025-09-17

---
1. Document-level / openapi version field

┌───────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬────────────────────────┐
│        Change         │                                                                                        Detail                                                                                         │   Additive/Breaking    │
├───────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────┤
│ openapi value         │ Must now match 3.2.x to use 3.2 features (meta-schema pattern ^3\.2\.\d+(-.+)?$). Semantics of the field itself unchanged ("SHOULD be used by tooling to interpret the document";     │ N/A (versioning)       │
│                       │ patch version SHOULD be ignored).                                                                                                                                                     │                        │
├───────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────┤
│ "Versions and         │ New formal deprecation policy: deprecated fields/features remain usable; expected to remain until next major version. Also explicitly states non-backwards-compatible changes MAY     │ Clarification          │
│ Deprecation" section  │ occur in minor versions "where impact is believed to be low".                                                                                                                         │                        │
├───────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────┤
│ Normative references  │ HTTP now RFC9110, JSON RFC8259, YAML 1.2 / RFC9512 (application/openapi+yaml context), XML namespaces RFC3987 (IRI).                                                                  │ Clarification          │
│ updated               │                                                                                                                                                                                       │                        │
├───────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────┤
│                       │ Formalized "entry document" concept, base-URI establishment rules ($self → encapsulating entity → retrieval URI → application default), new Appendix F (base URI                      │                        │
│ Multi-document OADs   │ determination/reference resolution examples) and Appendix G (parsing and resolution guidance, warnings on fragmentary parsing, implicit-connection resolution examples). Old 3.1      │ Clarification/additive │
│                       │ Appendix F (resolving security requirements in a referenced document) folded into Security Requirement Object via URI-based references.                                               │                        │
└───────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴────────────────────────┘

2. OpenAPI Object

┌───────┬────────────────────────────────────────────────────────────────────┬──────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Field │                                Type                                │   Req    │                                                                     Change                                                                     │
├───────┼────────────────────────────────────────────────────────────────────┼──────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ $self │ string (URI reference, RFC3986; MUST NOT contain a fragment —      │ Optional │ New. Self-assigned URI of the document; serves as its base URI (RFC3986 §5.1.1). If relative, resolved against the next base-URI source.       │
│       │ meta-schema pattern ^[^#]*$)                                       │          │ References MUST use the target document's $self when present.                                                                                  │
└───────┴────────────────────────────────────────────────────────────────────┴──────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

No other OpenAPI Object field changes (jsonSchemaDialect, webhooks, etc. unchanged from 3.1).

3. Info / Contact / License Objects

No field changes. (info.summary and license.identifier (SPDX, mutually exclusive with url) already existed in 3.1.)

4. Server Object / Server Variable Object

┌────────────────────────────────┬────────┬──────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│             Field              │  Type  │   Req    │                                                                   Change                                                                   │
├────────────────────────────────┼────────┼──────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ name                           │ string │ Optional │ New. "An optional unique string to refer to the host designated by the URL."                                                               │
├────────────────────────────────┼────────┼──────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ url                            │ string │ Required │ Tightened: "Query and fragment MUST NOT be part of this URL" (previously undefined; technically breaking for documents that relied on it). │
├────────────────────────────────┼────────┼──────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ (Server Variable substitution) │ —      │ —        │ Formal ABNF syntax for server URL templating, incorporating RFC6570 errata 6937. New "Examples of API Base URL Determination" section.     │
└────────────────────────────────┴────────┴──────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

Server Variable Object: no field changes.

5. Components Object

┌────────────┬───────────────────────────────────────────────────┬──────────┬─────────────────────────────────────────────────────────────────────────────┐
┌──────────────────────┬────────────────────────────┬──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│        Field         │            Type            │   Req    │                                                                                 Change                                                                                  │
├──────────────────────┼────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ query                │ Operation Object           │ Optional │ New. QUERY HTTP method per draft-ietf-httpbis-safe-method-w-body (safe, idempotent query with body).                                                                    │
├──────────────────────┼────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ additionalOperations │ Map[string, Operation      │ Optional │ New. Custom/other HTTP methods; map key is the method name with the exact capitalization sent on the wire; MUST NOT contain entries for methods covered by fixed fields │
│                      │ Object]                    │          │  (no POST, no QUERY, etc.).                                                                                                                                             │
├──────────────────────┼────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ (Path templating)    │ —                          │ —        │ Formal ABNF for path templates. Path parameter values MUST NOT contain unescaped /, ?, # (carried from 3.1, expanded percent-encoding guidance).                        │
└──────────────────────┴────────────────────────────┴──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

7. Operation Object

No new fields. (responses remains optional as in 3.1.)

8. Parameter Object

┌───────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬─────────────────────────────────────────────┐
│      Change       │                                                                               Detail                                                                                │              Additive/Breaking              │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│                   │ New location value. Treats the entire URL query string as one value; MUST be described with content (never schema/style/explode/allowReserved); MUST NOT appear     │                                             │
│ in: "querystring" │ more than once; MUST NOT coexist with any in: "query" parameter in the same operation/path item; name is not used in serialization. Enables JSON-in-querystring,    │ Additive                                    │
│                   │ JSONPath, etc.                                                                                                                                                      │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ style: "cookie"   │ New style value for in: "cookie": RFC6265 syntax, pairs separated by ;  (semicolon + space), no percent-encoding applied or removed. in: "cookie" default style     │ Additive (behavioral clarification: form    │
│                   │ remains "form" "for compatibility reasons" but style: "cookie" SHOULD be used. New Appendix D content on cookie serialization.                                      │ cookies were previously ill-defined)        │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│                   │ Scope broadened: 3.1 said "only applies to parameters with an in value of query"; 3.2 says it "only applies to in and style values that automatically               │                                             │
│ allowReserved     │ percent-encode" (so now usable e.g. with cookies using style: "form"). Description rewritten around RFC6570 reserved expansion + new "URL Percent-Encoding"         │ Additive/relaxation                         │
│                   │ section.                                                                                                                                                            │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ Fixed-field       │ Into "Common Fixed Fields", "Fixed Fields for use with schema", "Fixed Fields for use with content".                                                                │ Editorial                                   │
│ tables split      │                                                                                                                                                                     │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ New guidance      │ "Extending Support for Querystring Formats", note that name: "Cookie" with in: "header" is undefined.                                                               │ Clarification                               │
└───────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴─────────────────────────────────────────────┘

9. Request Body Object

No changes.

┌───────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬─────────────────────────────────────────────┐
│      Change       │                                                                               Detail                                                                                │              Additive/Breaking              │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│                   │ New location value. Treats the entire URL query string as one value; MUST be described with content (never schema/style/explode/allowReserved); MUST NOT appear     │                                             │
│ in: "querystring" │ more than once; MUST NOT coexist with any in: "query" parameter in the same operation/path item; name is not used in serialization. Enables JSON-in-querystring,    │ Additive                                    │
│                   │ JSONPath, etc.                                                                                                                                                      │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ style: "cookie"   │ New style value for in: "cookie": RFC6265 syntax, pairs separated by ;  (semicolon + space), no percent-encoding applied or removed. in: "cookie" default style     │ Additive (behavioral clarification: form    │
│                   │ remains "form" "for compatibility reasons" but style: "cookie" SHOULD be used. New Appendix D content on cookie serialization.                                      │ cookies were previously ill-defined)        │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│                   │ Scope broadened: 3.1 said "only applies to parameters with an in value of query"; 3.2 says it "only applies to in and style values that automatically               │                                             │
│ allowReserved     │ percent-encode" (so now usable e.g. with cookies using style: "form"). Description rewritten around RFC6570 reserved expansion + new "URL Percent-Encoding"         │ Additive/relaxation                         │
│                   │ section.                                                                                                                                                            │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ Fixed-field       │ Into "Common Fixed Fields", "Fixed Fields for use with schema", "Fixed Fields for use with content".                                                                │ Editorial                                   │
│ tables split      │                                                                                                                                                                     │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ New guidance      │ "Extending Support for Querystring Formats", note that name: "Cookie" with in: "header" is undefined.                                                               │ Clarification                               │
└───────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴─────────────────────────────────────────────┘

9. Request Body Object

No changes.

10. Media Type Object

┌────────────────┬──────────────────────┬──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│     Field      │         Type         │   Req    │                                                                                       Change                                                                                        │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ itemSchema     │ Schema Object        │ Optional │ New. Schema for each item of a sequential media type (each event/line/part).                                                                                                        │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ prefixEncoding │ [Encoding Object]    │ Optional │ New. Positional encoding ("Encoding By Position"); multipart only; MUST NOT coexist with encoding.                                                                                  │
│                │ (array)              │          │                                                                                                                                                                                     │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ itemEncoding   │ Encoding Object      │ Optional │ New. One Encoding Object applied to all (remaining) array items; multipart only; MUST NOT coexist with encoding.                                                                    │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ encoding       │ Map[string, Encoding │ Optional │ Changed: no longer restricted to Request Body Objects (3.1: "SHALL only apply to Request Body Objects"); now applies wherever the media type is multipart or                        │
│                │  Object]             │          │ application/x-www-form-urlencoded (e.g. querystring parameters, responses). MUST NOT coexist with prefixEncoding/itemEncoding.                                                      │
└────────────────┴──────────────────────┴──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
│                   │ New location value. Treats the entire URL query string as one value; MUST be described with content (never schema/style/explode/allowReserved); MUST NOT appear     │                                             │
│ in: "querystring" │ more than once; MUST NOT coexist with any in: "query" parameter in the same operation/path item; name is not used in serialization. Enables JSON-in-querystring,    │ Additive                                    │
│                   │ JSONPath, etc.                                                                                                                                                      │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ style: "cookie"   │ New style value for in: "cookie": RFC6265 syntax, pairs separated by ;  (semicolon + space), no percent-encoding applied or removed. in: "cookie" default style     │ Additive (behavioral clarification: form    │
│                   │ remains "form" "for compatibility reasons" but style: "cookie" SHOULD be used. New Appendix D content on cookie serialization.                                      │ cookies were previously ill-defined)        │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│                   │ Scope broadened: 3.1 said "only applies to parameters with an in value of query"; 3.2 says it "only applies to in and style values that automatically               │                                             │
│ allowReserved     │ percent-encode" (so now usable e.g. with cookies using style: "form"). Description rewritten around RFC6570 reserved expansion + new "URL Percent-Encoding"         │ Additive/relaxation                         │
│                   │ section.                                                                                                                                                            │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ Fixed-field       │ Into "Common Fixed Fields", "Fixed Fields for use with schema", "Fixed Fields for use with content".                                                                │ Editorial                                   │
│ tables split      │                                                                                                                                                                     │                                             │
├───────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ New guidance      │ "Extending Support for Querystring Formats", note that name: "Cookie" with in: "header" is undefined.                                                               │ Clarification                               │
└───────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴─────────────────────────────────────────────┘

9. Request Body Object

No changes.

10. Media Type Object

┌────────────────┬──────────────────────┬──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│     Field      │         Type         │   Req    │                                                                                       Change                                                                                        │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ itemSchema     │ Schema Object        │ Optional │ New. Schema for each item of a sequential media type (each event/line/part).                                                                                                        │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ prefixEncoding │ [Encoding Object]    │ Optional │ New. Positional encoding ("Encoding By Position"); multipart only; MUST NOT coexist with encoding.                                                                                  │
│                │ (array)              │          │                                                                                                                                                                                     │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ itemEncoding   │ Encoding Object      │ Optional │ New. One Encoding Object applied to all (remaining) array items; multipart only; MUST NOT coexist with encoding.                                                                    │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ encoding       │ Map[string, Encoding │ Optional │ Changed: no longer restricted to Request Body Objects (3.1: "SHALL only apply to Request Body Objects"); now applies wherever the media type is multipart or                        │
│                │  Object]             │          │ application/x-www-form-urlencoded (e.g. querystring parameters, responses). MUST NOT coexist with prefixEncoding/itemEncoding.                                                      │
└────────────────┴──────────────────────┴──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

New normative sections: Sequential Media Types (application/jsonl, application/x-ndjson, application/json-seq and +json-seq suffix, application/geo+json-seq, text/event-stream, multipart/mixed) modeled as implicit arrays; Complete vsStreaming Content; Binary Streams; Special Considerations for Server-Sent Events (implementations MUST work with events as parsed per the WHATWG text/event-stream spec, retry modeled as integer, unspecified fields as strings); OpenAPI Media Type Registry (https://spec.openapis.org/registry/media-type/).

┌────────────────┬──────────────────────┬──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│     Field      │         Type         │   Req    │                                                                                       Change                                                                                        │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ itemSchema     │ Schema Object        │ Optional │ New. Schema for each item of a sequential media type (each event/line/part).                                                                                                        │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ prefixEncoding │ [Encoding Object]    │ Optional │ New. Positional encoding ("Encoding By Position"); multipart only; MUST NOT coexist with encoding.                                                                                  │
│                │ (array)              │          │                                                                                                                                                                                     │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ itemEncoding   │ Encoding Object      │ Optional │ New. One Encoding Object applied to all (remaining) array items; multipart only; MUST NOT coexist with encoding.                                                                    │
├────────────────┼──────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ encoding       │ Map[string, Encoding │ Optional │ Changed: no longer restricted to Request Body Objects (3.1: "SHALL only apply to Request Body Objects"); now applies wherever the media type is multipart or                        │
│                │  Object]             │          │ application/x-www-form-urlencoded (e.g. querystring parameters, responses). MUST NOT coexist with prefixEncoding/itemEncoding.                                                      │
└────────────────┴──────────────────────┴──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

New normative sections: Sequential Media Types (application/jsonl, application/x-ndjson, application/json-seq and +json-seq suffix, application/geo+json-seq, text/event-stream, multipart/mixed) modeled as implicit arrays; Complete vsStreaming Content; Binary Streams; Special Considerations for Server-Sent Events (implementations MUST work with events as parsed per the WHATWG text/event-stream spec, retry modeled as integer, unspecified fields as strings); OpenAPI Media Type Registry (https://spec.openapis.org/registry/media-type/).

11. Encoding Object

┌─────────────────────────────┬─────────────────────────┬──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│            Field            │          Type           │   Req    │                                                                               Change                                                                                │
├─────────────────────────────┼─────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ encoding                    │ Map[string, Encoding    │ Optional │ New. Nested encoding (same manner as Media Type Object's encoding), enabling nested multipart/form structures.                                                      │
│                             │ Object]                 │          │                                                                                                                                                                     │
├─────────────────────────────┼─────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ prefixEncoding              │ [Encoding Object]       │ Optional │ New. Nested positional encoding.                                                                                                                                    │
├─────────────────────────────┼─────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ itemEncoding                │ Encoding Object         │ Optional │ New. Nested item encoding.                                                                                                                                          │
├─────────────────────────────┼─────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ style/explode/allowReserved │ —                       │ —        │ Clarified precedence: if explicitly defined, contentType (implicit or explicit) SHALL be ignored; grouped as "Fixed Fields for RFC6570-style Serialization".        │
│                             │                         │          │ (contentType as comma-separated list already existed in 3.1.1.)                                                                                                     │
└─────────────────────────────┴─────────────────────────┴──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

New sections: Handling multiple contentType values, Content-Transfer-Encoding vs contentEncoding, examples incl. streaming multipart, byte ranges, nested multipart/mixed.

12. Responses Object

No changes (still MUST contain at least one response code). HTTP status code text moved under this object.

13. Response Object

┌─────────────┬────────┬────────────────────────────────────┬────────────────────────────────────────────────────────────────┐
│    Field    │  Type  │                Req                 │                             Change                             │
├─────────────┼────────┼────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ summary     │ string │ Optional                           │ New. Short summary of the response's meaning.                  │
├─────────────┼────────┼────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
│ description │ string │ Was REQUIRED in 3.1 → now Optional │ Relaxation (breaking only for strict validators expecting it). │
└─────────────┴────────┴────────────────────────────────────┴────────────────────────────────────────────────────────────────┘

14. Callback Object

No changes.

15. Example Object

┌─────────────────┬─────────────┬──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│      Field      │    Type     │   Req    │                                                                                           Change                                                                                            │
├─────────────────┼─────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ dataValue       │ Any         │ Optional │ New. In-memory/data-structure form; MUST validate against the relevant Schema Object; mutually exclusive with value.                                                                        │
├─────────────────┼─────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ serializedValue │ string      │ Optional │ New. Serialized form incl. encoding/escaping; if dataValue present SHOULD be its serialization; SHOULD NOT be used when the serialization target is JSON; mutually exclusive with value and │
│                 │             │          │  externalValue.                                                                                                                                                                             │
├─────────────────┼─────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ externalValue   │ string      │ Optional │ Redefined relative to dataValue/serializedValue; mutually exclusive with serializedValue and value.                                                                                         │
│                 │ (URI)       │          │                                                                                                                                                                                             │
├─────────────────┼─────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ value           │ Any         │ Optional │ Deprecated for non-JSON serialization targets — use dataValue/serializedValue instead.                                                                                                      │
└─────────────────┴─────────────┴──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

New normative subsections: "JSON-Compatible and value-Safe Examples", "Choosing Which Field(s) to Use", "Criteria for serializedExample", "Validating Examples".

16. Link Object

No field changes. Runtime expressions get a formalized ABNF.

17. Header Object

No new fields (no allowReserved; style still "simple" only). Fixed fields reorganized into Common / schema / content groups. New guidance sections: "Modeling Link Headers", "Representing the Set-Cookie Header" (multiple Set-Cookie values can't be comma-joined; modeled as a single header or via content).

18. Tag Object

┌─────────┬────────┬──────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│  Field  │  Type  │   Req    │                                                                  Change                                                                   │
├─────────┼────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ summary │ string │ Optional │ New. Short display summary.                                                                                                               │
├─────────┼────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ parent  │ string │ Optional │ New. Name of the parent tag; the named tag MUST exist in the API description; circular parent/child references MUST NOT be used.          │
├─────────┼────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ kind    │ string │ Optional │ New. Machine-readable category; any string; common values nav, badge, audience; registry at https://spec.openapis.org/registry/tag-kind/. │
└─────────┴────────┴──────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

19. Reference Object

No changes ($ref + sibling summary/description as in 3.1).

20. Schema Object / JSON Schema dialect

- No dialect change. Default remains JSON Schema draft 2020-12; the OAS dialect schema id is still https://spec.openapis.org/oas/3.1/dialect/base (verified in published 3.2.0 HTML). jsonSchemaDialect behavior unchanged.
- No new schema keywords. example remains deprecated in favor of examples.
- Data Types / format sections moved under Schema Object; format table unchanged (int32, int64, float, double, password).
- New/expanded guidance: "Parsing and Serializing" (JSON/non-JSON/binary data), "Non-Validating Constraint Keywords", XML modeling, annotated enumerations, generic data structures.

21. Discriminator Object

┌────────────────┬─────────────────────────┬─────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│     Field      │          Type           │                 Req                 │                                                                        Change                                                                         │
├────────────────┼─────────────────────────┼─────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                │ string (schema name or  │ Optional (required if               │                                                                                                                                                       │
│ defaultMapping │ URI reference)          │ discriminating property is          │ New. Schema used when the discriminating property is absent or its value has no explicit/implicit mapping.                                            │
│                │                         │ optional)                           │                                                                                                                                                       │
├────────────────┼─────────────────────────┼─────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ propertyName   │ string                  │ Still REQUIRED (field)              │ Semantics changed: the discriminating property MAY now be optional in the payload schema (3.1: SHOULD be required, absent = undefined); if optional,  │
│                │                         │                                     │ defaultMapping MUST be present.                                                                                                                       │
├────────────────┼─────────────────────────┼─────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ mapping        │ —                       │ —                                   │ Clarified: ambiguous values (valid schema name and valid relative URI) are implementation-defined, RECOMMENDED treated as schema name; authors MUST   │
│                │                         │                                     │ prefix with ./ to force URI interpretation. Mapping keys MUST be strings; tooling MAY stringify payload values (implementation-defined).              │
└────────────────┴─────────────────────────┴─────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

22. XML Object

┌───────────┬───────────────────────────────────────┬──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│   Field   │                 Type                  │   Req    │                                                                                 Change                                                                                  │
├───────────┼───────────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ nodeType  │ string: element, attribute, text,     │ Optional │ New. Default none if $ref/$dynamicRef/type: "array" present in the containing Schema Object, else element. New "XML Node Types" section (element lists,                 │
│           │ cdata, none                           │          │ implicit/explicit text nodes, CDATA, null handling).                                                                                                                    │
├───────────┼───────────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ attribute │ boolean                               │ Optional │ Deprecated — use nodeType: "attribute". MUST NOT be present if nodeType is present.                                                                                     │
├───────────┼───────────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ wrapped   │ boolean                               │ Optional │ Deprecated — use nodeType: "element". MUST NOT be present if nodeType is present.                                                                                       │
├───────────┼───────────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ namespace │ string                                │ Optional │ Changed: now an IRI (RFC3987), still non-relative (3.1: non-relative URI). Spec notes 3.1.0 and earlier erroneously said "absolute URI".                                │
└───────────┴───────────────────────────────────────┴──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

23. Security Scheme Object

┌───────────────────┬────────────────────────────┬────────────┬──────────┬───────────────────────────────────────────────────────────────────────────┐
│       Field       │            Type            │ Applies to │   Req    │                                  Change                                   │
├───────────────────┼────────────────────────────┼────────────┼──────────┼───────────────────────────────────────────────────────────────────────────┤
│ oauth2MetadataUrl │ string (URL, TLS required) │ oauth2     │ Optional │ New. URL of OAuth2 authorization server metadata (RFC8414).               │
├───────────────────┼────────────────────────────┼────────────┼──────────┼───────────────────────────────────────────────────────────────────────────┤
│ deprecated        │ boolean (default false)    │ Any type   │ Optional │ New. Marks the scheme deprecated; consumers SHOULD refrain from using it. │
├───────────────────┼────────────────────────────┼────────────┼──────────┼───────────────────────────────────────────────────────────────────────────┤
│ type              │ —                          │ —          │ —        │ Unchanged value set (apiKey, http, mutualTLS, oauth2, openIdConnect).     │
└───────────────────┴────────────────────────────┴────────────┴──────────┴───────────────────────────────────────────────────────────────────────────┘

24. OAuth Flows Object / OAuth Flow Object

┌─────────────────────────────────────┬───────────────────┬───────────────────────────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                Field                │       Type        │                  Req                  │                                               Change                                                │
├─────────────────────────────────────┼───────────────────┼───────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ deviceAuthorization (OAuth Flows)   │ OAuth Flow Object │ Optional                              │ New. OAuth 2.0 Device Authorization Grant (RFC8628) flow.                                           │
├─────────────────────────────────────┼───────────────────┼───────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ deviceAuthorizationUrl (OAuth Flow) │ string (URL, TLS) │ REQUIRED for deviceAuthorization flow │ New.                                                                                                │
├─────────────────────────────────────┼───────────────────┼───────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ tokenUrl (OAuth Flow)               │ —                 │ —                                     │ Now REQUIRED for deviceAuthorization in addition to password, clientCredentials, authorizationCode. │
└─────────────────────────────────────┴───────────────────┴───────────────────────────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────┘

The implicit and password flows are not marked deprecated in 3.2 (rumors to the contrary are false).

25. Security Requirement Object

- Changed: each key may now be a name or a URI — "Each name or URI MUST correspond to a security scheme" (3.1: name MUST be declared under Components). Enables referencing security schemes across documents without a Components entry; replaces 3.1's Appendix F guidance.

26. Webhooks, External Docs, Specification Extensions

No changes.

---
Summary classification

- Breaking (strict sense): none intended; two edge tightenings — Server url now explicitly forbids query/fragment; XML attribute/wrapped MUST NOT coexist with nodeType (only relevant to new docs).
- Relaxations: Response description optional; discriminating property may be optional; allowReserved beyond in: query; Security Requirement keys may be URIs.
- Deprecations (non-removing): xml.attribute, xml.wrapped, Example value for non-JSON targets, plus per-scheme deprecation via the new deprecated field.
- Everything else is additive: $self, query/additionalOperations, in: querystring, style: cookie, itemSchema/prefixEncoding/itemEncoding, nested Encoding, components.mediaTypes, response.summary, dataValue/serializedValue,tag.summary/parent/kind, discriminator.defaultMapping, xml.nodeType, oauth2MetadataUrl, security scheme deprecated, deviceAuthorization flow, server.name.
- JSON Schema dialect: unchanged (draft 2020-12; OAS dialect id still …/oas/3.1/dialect/base).

# Supporting OpenAPI 3.2 in oaskit

**TL;DR: The upgrade is very tractable.** OpenAPI 3.2 (released September 2025) keeps the JSON Schema dialect at draft 2020-12 — so jsv needs no changes — and almost every 3.1 document is a valid 3.2 document. Oaskit has no version-dispatch logic anywhere (the `openapi` field isn't even enforced; `"openapi" => "hello"` casts fine per `test/oaskit/spec_test.exs:15`), so this is not a "fork the model per version" project. It's roughly: a batch of mechanical field additions to `Oaskit.Spec.*` modules, one moderate feature (the QUERY method + `additionalOperations`), and a set of runtime-validation semantics you can adopt incrementally.

One caveat on current behavior: since spec modules only normalize known keys, a user handing you a 3.2 document today gets the new fields **silently dropped** during `normalize!`. So "supporting 3.2" mostly means teaching the object model about the new fields so they survive normalization, casting, and `mix openapi.dump`.

## Tier 1 — Mechanical field additions (bulk of the diff, low risk)

Each is a new optional field in a `defschema` + its `normalize!/2` in one self-contained module:

| Module                    | Addition                                                                                                                          |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `spec/open_api.ex`        | `$self` (URI string, no fragment) — the document's self-assigned base URI                                                         |
| `spec/server.ex`          | `name`                                                                                                                            |
| `spec/tag.ex`             | `summary`, `parent`, `kind` (tag hierarchy — one of 3.2's headline features)                                                      |
| `spec/response.ex`        | `summary`; also `description` is **no longer required** in 3.2                                                                    |
| `spec/security_scheme.ex` | `oauth2MetadataUrl` (RFC 8414), `deprecated`                                                                                      |
| `spec/o_auth_flows.ex`    | `deviceAuthorization` flow; `spec/o_auth_flow.ex`: `deviceAuthorizationUrl` (required for that flow, and `tokenUrl` required too) |
| `spec/discriminator.ex`   | `defaultMapping`                                                                                                                  |
| `spec/xml.ex`             | `nodeType` (element/attribute/text/cdata/none); `attribute` and `wrapped` become deprecated and MUST NOT coexist with `nodeType`  |
| `spec/example.ex`         | `dataValue`, `serializedValue` (with mutual-exclusion rules against `value`/`externalValue`)                                      |
| `spec/media_type.ex`      | `itemSchema`, `itemEncoding`, `prefixEncoding` (fields only; runtime semantics are Tier 3)                                        |
| `spec/encoding.ex`        | nested `encoding`, `itemEncoding`, `prefixEncoding`                                                                               |

Plus cosmetics: the auto-generated doc links point at `v3.1.1.html` (`lib/oaskit/internal/spec_object.ex:40`), and `mix.exs` description/doc-group and the guides say 3.1.

`components.mediaTypes` is also new (Media Type Objects become referenceable) — the field is trivial, but it touches ref resolution in `spec_builder.ex` (`resolve_ref/3` walks Components by kind), so it's the one Components change that isn't purely mechanical.

## Tier 2 — HTTP methods (the one structural change)

3.2 adds the `query` operation (the new QUERY HTTP method) and `additionalOperations` (map of arbitrary method name → Operation, exact wire capitalization, must not overlap the fixed verbs).

The verb list is centralized in `PathItem.verbs/0` (`lib/oaskit/spec/path_item.ex:4`) but re-hardcoded in the schema properties (lines 21–28) and `normalize!` (lines 48–55), and consumed by the `Enumerable` impl, `SpecBuilder.buildable_operations`, and `method_to_verb/1` in `plugs/validate_request.ex:400`. Adding `query` is straightforward. `additionalOperations` is more work:

- The `Enumerable` impl over PathItem (which drives operation building) needs to yield `{method_string, operation}` pairs beyond the eight atoms.
- Request matching in `ValidateRequest` currently uppercases fixed verbs; custom methods need an exact-case string lookup.
- The controller DSL (`operation` macro) already accepts any atom as `:method` (`controller.ex:681-710`), which helps — but the normalizer must route non-standard methods into `additionalOperations` instead of a PathItem property.
- Practical note: Phoenix's router has no `query` macro, so users would declare routes via `match :query, ...` — worth a guide section and a test in `test/support/test_web/router.ex`.

## Tier 3 — Runtime validation semantics (adopt incrementally)

These are where 3.2 adds *behavior*, not just fields. None block declaring 3.2 support for spec generation/casting; each is an independent feature for the validation side:

- **`in: "querystring"` parameters** — the whole query string as one `content`-described value (JSON-in-querystring etc.), with mutual-exclusion rules against `in: query`. Needs new deserialization logic in the request validator.
- **Sequential media types / streaming** (`itemSchema` for `application/jsonl`, `text/event-stream`, etc.). For a buffering Plug validator this is largely out of scope; you could validate complete JSONL bodies item-by-item and leave SSE to documentation-only support. I'd ship the fields and explicitly defer the validation.
- **`style: "cookie"`** serialization and the broadened `allowReserved` semantics — touches parameter deserialization.
- **Security Requirement keys may be URIs** (not just Components names) — touches security-scheme resolution in the builder.
- Optional strictness: 3.2 explicitly forbids query/fragment in `server.url` and requires non-empty `enum` in Server Variables; you could add those constraints or not (oaskit doesn't enforce today).

## What you *don't* have to do

- No JSON Schema work: dialect is still 2020-12, and even the OAS dialect id stays `…/oas/3.1/dialect/base`. jsv `~> 0.19` is fine as-is.
- No version branching: since 3.2 is (deliberately) a near-superset of 3.1, the pragmatic route is a single object model that accepts both, exactly as the code is structured now. Users declare `openapi: "3.1.1"` or `"3.2.0"` themselves in their `spec/0`.
- OAuth `implicit`/`password` flows are **not** deprecated in 3.2 (a common misconception) — nothing to change there.

## Suggested order

1. Tier 1 field batch + doc-link/version-string updates + a 3.2 fixture document in `test/support/data/` (there are 3.2 versions of common samples like Train Travel API).
2. `query` verb + `additionalOperations`.
3. Cherry-pick Tier 3 by demand — `querystring` parameters and JSONL `itemSchema` validation are the ones users will actually ask for.

Drive-by finding worth fixing regardless: in `lib/oaskit/spec/security_scheme.ex` the `oneOf` branch for `mutualTLS` requires `openIdConnectUrl`, which looks like a copy-paste bug — `mutualTLS` requires neither per the spec.