# Limitations

The goal of this library is not to implement everything that is possible under
the OpenAPI Specification, but rather to describe all that is possible with the
Phoenix framework in valid OpenAPI terms.

Hence there are some OpenAPI capabilities that are not supporded because we want
to rely on Phoenix and Plug as much as possible to do the heavy listing.


## Path parameters deserialization

Path parameters are handled by the Phoenix router when a route specifies a
parameter segment, like `id` in `/users/:id`.

Oaskit will not support special parameter styles like `label` or `matrix` here.
Only `simple` is supported with `explode` set to `false`. Other configurations
will lead to inconsistencies.


## Query string parameters cast

Query string values are always defined as strings, but Oaskit allows to define a
schema with a different type like `integer` or `boolean`.

```elixir
operation :my_operation,
  parameters: [
    string_param: [in: :query, schema: string()],
    boolean_param: [in: :query, schema: boolean()],
    integer_param: [in: :query, schema: integer()],
    number_param: [in: :query, schema: number()]
  ]
```

Oaskit will parse the input parameters according to the schema for the following
types:

* `integer`
* `number`
* `boolean`
* `array` with `items` of the above types.

Other types should be handled by the schema directly.


## Exploded array query string parameters

Oaskit supports `explode: true` for query string parameters. It is actually the
default value in OpenAPI 3.1.

Phoenix expect query parameters to use the `[]` notation when an array is
expected:

```text
?users[]=Alice&users[]=Bob
```

And parses it as this:

```elixir
%{"users" => ["Alice", "Bob"]}
```

OpenAPI allows parameters to be defined as arrays, and expect the underlying
implementation to make an array out of it:

```text
?users=Alice&users=Bob         # This will not work with Phoenix/Oaskit
```

Oaskit relies on Phoenix to parse the query parameters, as the Plug pipeline
will replace the query parameters in the `conn` before it reaches Oaskit code.

### Parameter validation

Given those circumstances, when a parameter name is defined as `"users[]"` (for
instance in an external OpenAPI specification imported in Oaskit), Oaskit will
strip the brackets on validation, expecting a `"users"` key in the
`conn.query_params` parsed by Phoenix.

If a custom parser passes `%{"users[]" => [...]}`, Oaskit will not use that
value and will consider the parameter as missing, leading to a 400 error if the
parameter is mandatory.

### Spec generation

When dumping the OpenAPI to JSON, Oaskit will automatically add the `[]` suffix
in the parameter names if it can detect that the parameter has a schema that
validates an array. Detection of the schema type is best effort and will work if
the parameter JSON schema has the `array` type, or if it is a reference to a
schema with the `array` type.

In the other cases that cannot be detected, the parameter name should contain
the brackets suffix. For instance:

```elixir
operation :show_users,
  operation_id: "ShowUsers",
  parameters: [
    "users_ids[]": [
      in: :query,
      # Schema does not matter, Oaskit will not strip the suffix
      # if the schema does not have the array type.
      schema: ...
    ],
```


## Query strings parameters style

Parameter styles like `matrix` or `label` are ignored. The schema given to the
parameter must be able to handle the raw parameter value returned by the Phoenix
parser.

This means the schema should accept a string. Use
[JSV cast functions](https://hexdocs.pm/jsv/cast-functions.html) in your schemas
to turn the value into something else.