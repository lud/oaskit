defmodule Oaskit.Controller do
  alias Oaskit.Spec.Operation
  alias Oaskit.Spec.Parameter
  alias __MODULE__

  @moduledoc """
  Provides macros to define OpenAPI operations directly from controllers.

  Macros requires to `use #{inspect(__MODULE__)}` from your controllers. This
  can be done wherever `use Phoenix.Controller` is called. With Phoenix, this is
  generally in your `MyAppWeb` module, in the `controller` function:

      defmodule MyAppWeb do
        def controller do
          quote do
            use Phoenix.Controller,
              formats: [:html, :json],
              layouts: [html: MyAppWeb.Layouts]

            use Oaskit.Controller # <-- Add it there once for all

            use Gettext, backend: MyAppWeb.Gettext

            import Plug.Conn

            # This is also where you will plug the validation
            plug Oaskit.Plugs.ValidateRequest

            unquote(verified_routes())
          end
        end
      end


  It can also be useful to define a new `api_controller` function, to separate
  controllers that define an HTTP API.

  You would then use that function in your API controllers:

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :api_controller

        # ...
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: binding() do
      import Controller

      Module.register_attribute(__MODULE__, :oaskit_parameters, accumulate: true)
      Module.register_attribute(__MODULE__, :oaskit_tags, accumulate: true)
      Module.register_attribute(__MODULE__, :oaskit_operations, accumulate: true)

      @before_compile Controller
    end
  end

  @doc """
  Defines an OpenAPI operation for the given Phoenix action (the function listed
  in the router that will handle the conn) that can be validated automatically
  with the `#{inspect(Oaskit.Plugs.ValidateRequest)}` plug automatically.

  This macro accepts the function name and a list of options that will define an
  `#{inspect(Operation)}`.

  ## Options

  * `:operation_id` - The ID of the operation that is used throughout the
    validation features. If missing, an id is automatically generated. Operation
    IDs must be unique.
  * `:tags` - A list of tags (strings) to attach to the operation.
  * `:description` - An optional string to describe the operation in the OpenAPI
    spec.
  * `:summary` - A short summary of what the operation does.
  * `:parameters` - A keyword list with parameter names as keys and parameter
    definitions as values. Parameters are query params but also path params. See
    below for more information.
  * `:request_body` - A map of possible content types and responses definitions.
    A schema module can be given directly to define a single
  * `:responses` - A map or keyword list where keys are status codes (integers
    or atoms) and values are responses definitions. See below for responses
    formats.

  Pass `false` instead of the options to ignore an action function.

  ## Defining parameters

  Parameters are organized by their name and their `:in` option. Two parameters
  with the same key can coexist if their `:in` option is different. The `:query`
  and `:path` values for `:in` are currently supported.

  Parameters support the following options:

  * `:in` - Either `:path` or `:query`. Required.
  * `:schema` - A JSON schema or Module name exporting a `schema/0` function.
  * `:required` - A boolean, defaults to `true` for `:path` params, `false`
    otherwise.
  * `:examples` - A list of examples.

  Parameters are stored into `conn.private.oaskit.path_params` and
  `conn.private.oaskit.query_params`. They do not override the `params`
  argument passed to your phoenix action function. Those original `params` are
  still the ones as decoded by phoenix.

  ### Parameters example

      # Imaginary GET /api/users/:organization route

      operation :list_users,
        operation_id: "ListUsers",
        parameters: [
          organization: [in: :path,  required: true,  schema: %{type: :string}],
          page:         [in: :query, required: false, schema: %{type: :integer, minimum: 1}],
          per_page:     [in: :query, required: false, schema: %{type: :integer, minimum: 1}]
        ],
        # ...

      def list_users(conn, _params) do
        page = query_param(conn, :page)
        per_page = query_param(conn, :per_page)
        do_something_with(conn, page, per_page)
      end

  ## Defining the request body

  Request bodies can be defined in two ways: Either by providing a mapping of
  content-type to media type objects, or with a shortcut by providing only a
  schema for an unique `"application/json"` content-type.

  The body can be retrieved in `conn.oaskit.private.body_params`.

  Options supported with a generic definition, for each content type:

  * `:content` - A map of content-type to bodies definitions. Content-types
    should be strings.
  * `:required` - A boolean. When `false`, the body can be missing and will not
    be validated. In that case, `conn.oaskit.private.body_params` will be
    `nil`. The default value is `false`.

  When using the shortcut, a single atom or 2-tuple is expected.

  * Supported atoms are `true` (a JSON schema that accepts anything), `false` (a
    JSON schema that rejects everything) or a module name. The module must
    export a `json_schema/0` function that returns a JSON schema.
  * When passing a tuple, the first element is a schema (boolean or module), but
    a direct JSON schema map (like `%{type: :object, ...}`) is also accepted.
    The second tuple element is a list of options for the response body object.

  **Important**, when using the shortcut, we chose to automatically define the
  `:required` option of the media type object to `true`.

  ### Request body examples

  A short form using a module schema:

      operation :create_user,
        operation_id: "CreateUser",
        request_body: UserSchema,
        # ...

      def create_user(conn, _params) do
        case Users.create_user(conn.private.oaskit.body_params) do
          # ...
        end
      end

  The operation definition above is equivalent to this:

      operation :create_user,
        operation_id: "CreateUser",
        request_body: [
          content: %{"application/json" => %{schema: CreateUserPayload}},
          required: true
        ],
        # ...

  To make the body non-required in the short form, use the tuple version:

      operation :create_user,
        operation_id: "CreateUser",
        request_body: {UserSchema, required: false},
        # ...

  Multiple content-types can be supported. Content-types with wildcards will be
  tried last by `#{inspect(Plug.Parsers)}`, as well as oaskit when choosing
  the schema for validation.

      operation :create_user,
        request_body: [
          content: %{
            "application/x-www-form-urlencoded" => %{schema: CreateUserPayload},
            "application/json" => %{schema: CreateUserPayload},
            "*/*" => %{schema: %{type: :string}}
          }
        ]

  ## Defining responses

  Responses are defined by a mapping of HTTP statuses to response objects.

  * HTTP statuses can be given as integers (`200`, `404`, _etc._) or atoms
    supported by `#{inspect(Plug.Conn.Status)}` like `:ok`, `:not_found`, _etc_.
  * `:default` can be given instead of a status to define the default option
    supported by the OpenAPI speficication. This is often used to define a
    generic error response.

  Response objects accept the following options:

  * `:description` - This is mandatory for responses.
  * `:headers` and `:links` - This is not used by the validation mechanisms of
    this library, but is useful to be defined in the OpenAPI specification JSON
    document.
  * `:content` - A mapping of content-type to media type objects, exactly as in
    the request bodies definitions.

  Finally, the response for each status can also be defined with a shortcut, by
  using a single schema that will be associated to the `"application/json"`
  content-type. The mandatory description can be provided when using the tuple
  shortcut, or will otherwise being pulled from the schema `description`
  keyword.

  ### Reponse examples

  A first example using the atom statuses, and a shortcut for the full response
  definition:

      operation :list_users,
        operation_id: "ListUsers",
        responses: [ok: UsersListPage]

  The definition above is equivalent to the following:

      operation :list_users,
        operation_id: "ListUsers",
        responses: %{
          200 => [
            description: UsersListPage.json_schema().description,
            content: %{
              "application/json" => %{schema: UsersListPage}
            }
          ]
        }

  The description can be overriden when using the shortcut:

      operation :list_users,
        operation_id: "ListUsers",
        responses: [ok: {UsersListPage, description: "A page of users"}]

  Multiple status codes are generally expected. The shortcut can be used in only
  a part of them.

      operation :list_users,
        operation_id: "ListUsers",
        responses: [
          ok: UsersListPage,
          not_found: {GenericErrorSchema, description: "not found generic response"},
          forbidden: {%{type: :array}, description: "missing-role messages"},
          internal_server_error: [
            description: "Error with stacktrace",
            content: %{
              "application/json" => [
                schema: %{type: :array, items: %{type: :string, description: "trace item"}}
              ],
              "text/plain" => [schema: true]
            }
          ]
        ]

  Of course, mixing all styles together is discouraged for readability.

  ## Ignore operations



  """
  @doc group: "Controller Macros"
  defmacro operation(action, spec)

  defmacro operation(action, false) do
    quote do
      @oaskit_operations {unquote(action), false, nil}
    end
  end

  defmacro operation(action, spec) when is_atom(action) and is_list(spec) do
    spec = maybe_expand_aliases(spec, __CALLER__)
    spec = ensure_operation_id(spec, action, __CALLER__)
    module = __CALLER__.module

    quote bind_quoted: binding() do
      {verb, spec} = Controller.__pop_verb(spec)

      shared_parameters =
        :lists.reverse(Module.get_attribute(__MODULE__, :oaskit_parameters, []))

      shared_tags =
        :lists.flatten(:lists.reverse(Module.get_attribute(__MODULE__, :oaskit_tags, [])))

      operation =
        Operation.from_controller!(spec,
          shared_parameters: shared_parameters,
          shared_tags: shared_tags,
          controller: module,
          action: action
        )

      @oaskit_operations {action, operation, verb}
    end
  end

  @doc """
  This macro allows Oaskit to validate request bodies, query and path
  parameters (and responses in tests) when an OpenAPI specification is not
  defined with the `operation/2` macro but rather provided directly in an
  external spec document.

  For instance with the following spec module:

      defmodule MyAppWeb.ExternalAPISpec do
        use Oaskit
        @api_spec JSON.decode!(File.read!("priv/api/spec.json"))

        @impl true
        def spec, do: @api_spec
      end

  Given the `spec.json` file decribes an operation whose `operationId` is
  `"ListUsers"`, then the request/response validation can be enabled like this:

      use_operation :list_users, "ListUsers"

      def list_users(conn, params) do
        # ...
      end

  > #### Parameter names always create atoms {: .warning}
  >
  > Query and path parameters defined in OpenAPI specifications always define
  > the corresponding atoms, even if that specification is read from a JSON
  > file, or defined manually in code with string keys.
  >
  > For that reason it is ill advised to use specs generated dynamically at
  > runtime without validating their content.
  """
  @doc group: "Controller Macros"
  defmacro use_operation(action, operation_id, opts \\ []) do
    opts = maybe_expand_aliases(opts, __CALLER__)

    quote bind_quoted: binding() do
      {verb, opts} = Controller.__pop_verb(opts)
      @oaskit_operations {action, {:use_operation, to_string(operation_id)}, verb}
    end
  end

  @doc """
  Defines a parameter for all operations defined _later_ in the module body with
  the `operation/2` macro.

  Takes the same options as the `:parameters` option items from that macro.

  If an operation also directly defines a parameter with the same `name` and
  `:in` option, it will take precedence and the parameter defined with
  `parameter/2` will be ignored.

  ## Example

  In the following example, the second operation defines its own version of the
  `per_page` parameter to limit the number of users returned in a single page.

      # This macro can be called multiple times
      parameter :slug, in: :path, schema: %{type: :string, pattern: "[0-9a-z-]+"}
      parameter :page, in: :query, schema: %{type: :integer, minimum: 1}
      parameter :per_page, in: :query, schema: %{type: :integer, minimum: 1, maximum: 100}

      operation :list_users, operation_id: "ListUsers", responses: [ok: UsersListPage]

      def list_users(conn, params) do
        # ...
      end

      operation :list_users_deep,
        operation_id: "ListUsersDeep",
        parameters: [
          per_page: [in: :query, schema: %{type: :integer, minimum: 1, maximum: 20}]
        ],
        responses: [
          ok:
            {DeepUsersListPage,
             description: "Returns users with all associated organization and blog posts data"}
        ]

      def list_users_deep(conn, params) do
        # ...
      end
  """
  @doc group: "Controller Macros"
  defmacro parameter(name, opts) when is_atom(name) do
    opts = maybe_expand_aliases(opts, __CALLER__)

    quote bind_quoted: binding() do
      @oaskit_parameters Parameter.from_controller!(name, opts)
    end
  end

  @doc """
  Defines tags for all operations defined _later_ in the module body with the
  `operation/2` macro.

  If an operation also directly defines tags, they will be merged.

  ## Example

      # This macro can be called multiple times
      tags ["users", "v1"]
      tags ["other-tag"]

      operation :list_users,
        operation_id: "ListUsers",
        responses: [ok: UsersListPage]

      def list_users(conn, params) do
        # ...
      end

      operation :list_users_deep,
        operation_id: "ListUsersDeep",
        tags: ["slow"],
        responses: [ok: DeepUsersListPage]

      def list_users_deep(conn, params) do
        # ...
      end
  """
  @doc group: "Controller Macros"
  defmacro tags(tags) when is_list(tags) do
    quote bind_quoted: binding() do
      @oaskit_tags tags
    end
  end

  if Code.ensure_loaded?(Phoenix) do
    def runtime? do
      Phoenix.plug_init_mode() == :runtime
    end
  else
    def runtime? do
      Process.get(__ENV__.function, false)
    end
  end

  defp maybe_expand_aliases(ast, caller) do
    if runtime?() && Macro.quoted_literal?(ast) do
      Macro.prewalk(ast, &expand_alias(&1, caller))
    else
      ast
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env) do
    Macro.expand(alias, %{env | function: {:init, 2}})
  end

  defp expand_alias(other, _env) do
    other
  end

  defp ensure_operation_id(spec, action, env) do
    case Keyword.fetch(spec, :operation_id) do
      {:ok, atom} when is_atom(atom) -> Keyword.put(spec, :operation_id, Atom.to_string(atom))
      {:ok, str} when is_binary(str) -> spec
      {:ok, _} -> spec
      :error -> Keyword.put(spec, :operation_id, operation_id_from_env(action, env))
    end
  end

  defp operation_id_from_env(action, env) do
    controller_name =
      env.module
      |> Atom.to_string()
      |> case do
        "Elixir." <> rest -> rest
        str -> str
      end
      |> unsuffix("Controller")

    # id prefix is the last part of the controller name
    id_prefix =
      controller_name
      |> String.split(".")
      |> List.last()
      |> Macro.underscore()

    # Hash the controller name to allow multiple controllers to have the same ID
    # prefix, for instance "Api.V1.User" and "Api.V2.User". Collisions can
    # happen but users are supposed to provide their own operation ids.
    mod_hash =
      controller_name
      |> then(&<<:erlang.phash2(&1, 2 ** 32)::little-32>>)
      |> Base.encode32(padding: false)

    "#{id_prefix}_#{to_string(action)}_#{mod_hash}"
  end

  defp unsuffix(value, suffix) do
    string = to_string(value)
    suffix_size = byte_size(suffix)
    prefix_size = byte_size(string) - suffix_size

    case string do
      <<prefix::binary-size(prefix_size), ^suffix::binary>> -> prefix
      _ -> string
    end
  end

  defmacro __before_compile__(env) do
    oaskit_operations = Module.delete_attribute(env.module, :oaskit_operations) || []
    _ = Module.delete_attribute(env.module, :oaskit_parameters)
    validate_duplicate_actions!(oaskit_operations, env)

    clauses =
      Enum.map(oaskit_operations, fn {action, operation, verb} ->
        case operation do
          false ->
            Controller._ignore_action(action)

          %Operation{} ->
            Controller._define_operation(action, operation, verb)

          {:use_operation, _} = using ->
            Controller._define_operation(action, using, verb)
        end
      end)

    quote do
      @doc false
      def __oaskit__(kind, action, arg)

      unquote(clauses)

      # undef catchall
      def __oaskit__(kind, action, arg) do
        :__undef__
      end
    end
  end

  @doc false
  def _ignore_action(action) do
    quote do
      def __oaskit__(_kind, unquote(action), _verb) do
        :ignore
      end
    end
  end

  @doc false
  def _define_operation(action, %Operation{} = operation, verb) when is_atom(action) do
    operation_id = operation.operationId
    operation = Macro.escape(operation)

    quote bind_quoted: binding() do
      @doc false

      match_verb = Controller.__verb_matcher(verb)

      # This is used by Paths.from_router / Paths.from_routes to retrieve
      # operations defined with the operation macro.
      def __oaskit__(:operation, unquote(action), unquote(match_verb)) do
        {:ok, unquote(Macro.escape(operation))}
      end

      # This is used by the ValidateRequest plug to retrieve the operation from
      # the phoenix controller/action.
      def __oaskit__(:operation_id, unquote(action), unquote(match_verb)) do
        {:ok, unquote(operation_id)}
      end
    end
  end

  def _define_operation(action, {:use_operation, operation_id}, verb) do
    quote bind_quoted: binding() do
      @doc false
      match_verb = Controller.__verb_matcher(verb)

      # This is used by the ValidateRequest plug to retrieve the operation from
      # the phoenix controller/action.
      def __oaskit__(:operation_id, unquote(action), unquote(match_verb)) do
        {:ok, unquote(operation_id)}
      end
    end
  end

  # Ensures that if multiple operations use the same controller function, a
  # :mehtod option is given to the `operation` or `use_operation` macro to be
  # able to match on it.
  defp validate_duplicate_actions!(oaskit_operations, env) do
    bad_cases =
      oaskit_operations
      |> Enum.filter(fn {_, definition, _verb} -> definition != false end)
      |> Enum.group_by(fn {action, _, _} -> action end, fn {_, op, verb} -> {op, verb} end)
      # Keep only groups with multiple operations on the same action, and where
      # at least one action does not provide the verb.
      |> Enum.flat_map(fn
        {_, []} ->
          []

        {_, [_]} ->
          []

        {action, [_, _ | _] = ops} ->
          without_verb = Enum.filter(ops, fn {_op, verb} -> verb == nil end)

          case without_verb do
            [] -> []
            rest -> [{action, rest}]
          end
      end)

    case bad_cases do
      [] ->
        :ok

      [{action, invalids} | _] ->
        op_ids = collect_op_ids(invalids)

        raise ArgumentError,
              "multiple operations defined for #{Exception.format_mfa(env.module, action, 2)}, " <>
                "please provide the :method option for operations #{inspect(op_ids)}"
    end
  end

  defp collect_op_ids(list) do
    Enum.map(list, fn
      {{:use_operation, op_id}, _verb} -> op_id
      {%Operation{operationId: op_id}, _verb} -> op_id
    end)
  end

  @doc false
  def __pop_verb(opts) do
    case Keyword.pop(opts, :method) do
      {nil, opts} -> {nil, opts}
      {v, opts} -> {validate_verb(v), opts}
    end
  end

  defp validate_verb(v) when not is_atom(v) do
    raise ArgumentError, "expected :method to be a lowercase atom, got: #{inspect(v)}"
  end

  defp validate_verb(v) do
    as_string = Atom.to_string(v)

    if String.downcase(as_string) != as_string do
      raise ArgumentError, "expected :method to be a lowercase atom, got: #{inspect(v)}"
    end

    v
  end

  # :post -> "POST" or _unused_var
  @doc false
  def __verb_matcher(nil) do
    Macro.var(:_any_verb, nil)
  end

  def __verb_matcher(verb) when is_atom(verb) do
    verb
  end

  @doc """
  Accepts a `Plug.Conn` struct, a parameter name (as atom) and a default value.

  Returns the validated parameter from `conn.oaskit.private.path_params` if
  found, or the default value.
  """
  def path_param(%Plug.Conn{} = conn, name, default \\ nil) do
    case conn do
      %{private: %{oaskit: %{path_params: %{^name => value}}}} -> value
      _ -> default
    end
  end

  @doc """
  Accepts a `Plug.Conn` struct, a parameter name (as atom) and a default value.

  Returns the validated parameter from `conn.oaskit.private.query_params` if
  found, or the default value.
  """
  def query_param(%Plug.Conn{} = conn, name, default \\ nil) do
    case conn do
      %{private: %{oaskit: %{query_params: %{^name => value}}}} -> value
      _ -> default
    end
  end

  @doc """
  Accepts a `Plug.Conn` struct, a parameter name (as atom) and a default value.

  Returns the validated parameter from `conn.oaskit.private.header_params` if
  found, or the default value.
  """
  def header_param(%Plug.Conn{} = conn, name, default \\ nil) do
    case conn do
      %{private: %{oaskit: %{header_params: %{^name => value}}}} -> value
      _ -> default
    end
  end

  @doc """
  Returns the validated body from the given `Plug.Conn` struct.
  """
  def body_params(%Plug.Conn{} = conn) do
    conn.private.oaskit.body_params
  end
end
