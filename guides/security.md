# Authorizing Requests

This guide covers the security parts of OpenAPI when using Oaskit.

## OpenAPI Security

OpenAPI 3.1 has support for authorization by describing security schemes and
security requirements.

This section gives a quick overview of those mechanisms. Please refer to the
[official documentation](https://learn.openapis.org/specification/security.html)
for further details.

### Security Schemes

Security schemes are defined in the `components` and describe how authentication
and authorization should be performed by consumers of an API.

This is purely informational in Oaskit! The library does not perform any
authentication using the described mechanisms; it's up to you to handle
authentication with the appropriate libraries.

In the following example, the API specification describes two security schemes,
`api_key` and `oauth`:

<!-- rdmx :section name:security_spec_example format:true -->
```elixir
defmodule MyAppWeb.ApiSpec do
  use Oaskit

  @impl true
  def spec do
    %{
      openapi: "3.1.1",
      info: %{title: "MyApp API", version: "1.0.0"},
      components: %{
        securitySchemes: %{
          api_key: %{
            description: "an API key",
            type: "apiKey",
            name: "api-key",
            in: "header"
          },
          oauth: %{
            type: "oauth2",
            flows: %{
              authorizationCode: %{
                authorizationUrl: "https://learn.openapis.org/oauth/2.0/auth",
                tokenUrl: "https://learn.openapis.org/oauth/2.0/token",
                scopes: %{
                  "some:scope1": "Some Description",
                  "some:scope2": "Some Description"
                }
              }
            }
          }
        }
      }
      # ... paths, servers, etc.
    }
  end
end
```
<!-- rdmx /:section -->

### Operation Level Security

OpenAPI operations accept a `security` option. These are security requirements
associating the name of a security scheme.

This option on operations _is_ read by Oaskit, but has to be handled by a custom
plug. Plug integration is described later in this document.

The `:security` option on the `operation` macro accepts a list of maps where the
map keys are names of the security schemes, and values are lists of required
roles or scopes. OpenAPI uses "roles" and "scopes" interchangeably depending on
the type of authentication.

In the following example, the operation should only be allowed for users
authenticated with the `api_key` security scheme with the `post:read` and
`post:create` roles.

<!-- rdmx :section name:security_operation_example format:true -->
```elixir
operation :create_post,
  operation_id: "CreatePost",
  request_body: PostSchema,
  security: [%{api_key: ["post:read", "post:create"]}]

def create_post(conn, _) do
  # ...
end
```
<!-- rdmx /:section -->

### Root Level Security

Security can be defined at the root level of the specification. In that case, it
applies to all operations that do not define the security option themselves. The
following example requires requests to all operations to be authenticated with
the `api_key` security scheme, but does not enforce any particular
scope.

<!-- rdmx :section name:security_spec_example format:true -->
```elixir
defmodule MyAppWeb.ApiSpec do
  use Oaskit

  @impl true
  def spec do
    %{
      openapi: "3.1.1",
      info: %{title: "MyApp API", version: "1.0.0"},
      components: %{
        securitySchemes: %{
          api_key: %{...}
        }
      },
      security: [%{api_key: []}]
    }
  end
end
```
<!-- rdmx /:section -->

When global security requirements are defined, operations can opt out of those
requirements by defining an empty list in the security option:

> To make security optional, an empty security requirement ({}) can be included
> in the array. This definition overrides any declared top-level security. To
> remove a top-level security declaration, an empty array can be used.
>
> [source](https://spec.openapis.org/oas/latest.html#operation-object)

<!-- rdmx :section name:security_operation_opt_out format:true -->
```elixir
operation :create_post,
  operation_id: "CreatePost",
  request_body: PostSchema,
  security: []

def create_post(conn, _) do
  # ...
end
```
<!-- rdmx /:section -->

Operations can also define more restrictive or different security requirements.
Remember that once the option is defined on an operation, the root-level option
is discarded for that operation. **If the root-level requirements must be
respected, they must be repeated in the operation-level option requirements.**

## Plug Integration

When the security option is defined on an operation (or globally at the root
level), Oaskit expects a custom plug to handle security verifications. Oaskit
does not know how to verify anything by itself.

Your plug must be set in the `:security` option when plugging
`Oaskit.Plugs.ValidateRequest`:

<!-- rdmx :section name:plug_1 format:true -->
```elixir
plug Oaskit.Plugs.ValidateRequest, security: MyApp.Plugs.ApiSecurity
```
<!-- rdmx /:section -->

### Plug Options

#### Using a module

When defined as a module, your plug will receive all options passed to the
request validation plug:

<!-- rdmx :section name:plug_2 format:true -->
```elixir
plug Oaskit.Plugs.ValidateRequest,
  security: MyApp.Plugs.ApiSecurity,
  pretty_errors: true,
  html_errors: false,
  custom_opt: "foo"
```
<!-- rdmx /:section -->

This plug will receive all other options, including the custom option that
Oaskit does not know about.

#### Using a module and custom options

It is also possible to pass options to the plug explicitly. In that case, the
plug will not receive any other options given to the request validation plug.

<!-- rdmx :section name:plug_3 format:true -->
```elixir
plug Oaskit.Plugs.ValidateRequest,
  # ... other options
  security: {MyApp.Plugs.ApiSecurity, log_level: :debug}
```
<!-- rdmx /:section -->

#### Extra options

Besides the plug level options, when invoked, your plug will receive two extra
options:

* The `:operation_id` from the operation to authorize.
* The `:security` requirements from the operation to authorize, defined on the
  operation or inherited from the root-level security.

Because of this, the options for plugs passed as a `{module, options}` tuple
must always be a keyword list, so the operation ID and the security requirements
can be injected.

## Disabling security

> ### The operations `:security` option must be handled {: .warning}
>
> If no custom plug is defined but one of your operations defines the `:security`
> option, or the root-level `:security` option is defined, Oaskit will default
> to returning a 401 response with a raw `"unauthorized"` body.
>
> This is made so nobody will expect that the security will be automatically
> enforced although Oaskit cannot know how to do it.
>
> Security requirements vary greatly between applications, and we want to make
> it explicit that you are responsible for protecting your API endpoints.

If you would rather implement authorization by other means, you can opt out of
the security mechanism by passing `false` instead of a plug to the request
validation plug:

<!-- rdmx :section name:plug_false format:true -->
```elixir
plug Oaskit.Plugs.ValidateRequest,
  security: false
```
<!-- rdmx /:section -->


## Security Lifecycle

### Authentication

**Authentication should not be handled in Oaskit validation**. You will
generally use libraries such as "mix phx.gen.auth", Pow, or Guardian to
authenticate requests.

These libraries use plugs at the endpoint or router level, well before the
request's `conn` enters any Oaskit code.

In general, those plugs will store user information in `conn.private` or
`conn.assigns`. This will be helpful to perform authorization with Oaskit. Make
sure that the roles or scopes are available in the conn data, or can be
retrieved easily from that data.

### Authorization

Your custom plug used in Oaskit security will be called with the operation ID
and the security requirements. This is a good place to validate authorization by
comparing the requirements with the user information stored in the conn.

* The `init/1` callback of your plug is first called with the options described
  in the related section above.
* The `call/2` callback of your plug is then called with the `conn` and the
  result of the `init/1` function.

Note that security validation happens **before** all other validations performed
by the `Oaskit.Plugs.ValidateRequest` plug. This prevents potential attack
vectors through the validation process itself. As a consequence, the
`Oaskit.Controller.body_params/1` and other helpers cannot be used from your
plug as those cast values are not yet defined in the conn.

### Authorization Logic Implementation

Your plug should implement the expected behavior from OpenAPI, but it's up to
you!

> A Security Requirement Object MAY refer to multiple security schemes in which
> case all schemes MUST be satisfied for a request to be authorized. This
> enables support for scenarios where multiple query parameters or HTTP headers
> are required to convey security information.
>
> When the security field is defined on the OpenAPI Object or Operation Object
> and contains multiple Security Requirement Objects, only one of the entries in
> the list needs to be satisfied to authorize the request. This enables support
> for scenarios where the API allows multiple, independent security schemes.
>
> [source](https://spec.openapis.org/oas/latest.html#security-requirement-object)

**Requirements Examples**

In the following example, the request should be authenticated with both
`api_key` and `oauth` (which may not make sense but it's an example!):

<!-- rdmx :section name:security_multi_map format:true -->
```elixir
operation :create_post,
  security: [
    %{
      api_key: ["post:read", "post:create"],
      oauth: ["posts"]
    }
  ]
```
<!-- rdmx /:section -->

In the following example, only one of the two authentication mechanisms is
required to allow the request.

<!-- rdmx :section name:security_multi_list format:true -->
```elixir
operation :create_post,
  security: [
    %{api_key: ["post:read", "post:create"]},
    %{oauth: ["posts"]}
  ]
```
<!-- rdmx /:section -->

After careful inspection of the incoming request, your plug can now return the
conn, either halted or not.

Your security plug **must** halt the `conn` to prevent unauthorized access. The
`Oaskit.Plugs.ValidateRequest` plug checks the `:halted` property of the `conn`:

* **If halted**: The request is stopped immediately. No further validation
occurs and the controller action is not called.
* **If not halted**: The request validation continues (body, params, etc.) and
your controller will be called if validation succeeds.

To halt the conn, use the `Plug.Conn.halt/1` function:

<!-- rdmx :section name:conn_halting format:true -->
```elixir
conn
|> put_status(401)
|> json(%{error: "Unauthorized"})
|> halt()
```
<!-- rdmx /:section -->

When the conn is halted, Phoenix or Plug will stop any further processing. This
means you can do anything with it, like rendering a custom JSON template or
redirecting to an authentication provider (provided the API consumer knows how
to handle that).

### After Authorization

If your custom plug returns a non-halted conn, the validation process follows
with body and parameters validation, as usual, before reaching your controller
action.

## Operations Without Security

The security plug is only called for operations that explicitly define the
`:security` option or when the root-level security is defined.

* Operations without this option will skip security validation entirely, unless
  security requirements are defined at the root level of your OpenAPI
  specification.
* Operations that define an empty security requirement list to override
  root-level security _will_ trigger the security mechanism and your plug will
  receive an empty list in the `:security` option.