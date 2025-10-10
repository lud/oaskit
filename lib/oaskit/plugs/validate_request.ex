defmodule Oaskit.Plugs.ValidateRequest do
  alias Oaskit.Errors.InvalidBodyError
  alias Oaskit.Errors.UnsupportedMediaTypeError
  alias Oaskit.Plugs.SpecProvider
  alias Oaskit.Validation.RequestData
  alias Oaskit.Validation.RequestValidator
  alias Plug.Conn
  require Logger

  @default_query_reader_opts [length: 1_000_000, validate_utf8: true]

  @moduledoc """
  This plug will match incoming requests to operations defined with the
  `#{inspect(Oaskit.Controller)}.operation/2` or
  `#{inspect(Oaskit.Controller)}.use_operation/2` macros and retrieved from a
  provided OpenAPI Specification module.

  ## Pluggin' in

  To use this plug in a controller, the
  `#{inspect(Oaskit.Plugs.SpecProvider)}` plug must be used in the router for
  the corresponding routes.

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        pipeline :api do
          plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.OpenAPISpec
        end

        scope "/api" do
          pipe_through :api

          scope "/users", MyAppWeb do
            get "/", UserController, :list_users
          end
        end
      end

  This plug must then be used in controllers. It is possible to call the plug in
  every controller where you want validation, or to define it globally in your
  `MyAppWeb` module.

  While you can directly patch the `MyAppWeb.controller` function if all your
  controllers belong to the HTTP API, we suggest to create a new
  `api_controller` function in your `MyAppWeb` module.

  Duplicate the `controller` function and add this plug and also `use
  Oaskit.Controller`.

      defmodule MyAppWeb do
        def controller do
          # ...
        end

        def api_controller do
          quote do
            use Phoenix.Controller, formats: [:json], layouts: []

            # Use the controller helpers to define operations
            use Oaskit.Controller

            use Gettext, backend: MyAppWeb.Gettext
            import Plug.Conn

            # Use the plug here. This has to be after `use Phoenix.Controller`.
            plug Oaskit.Plugs.ValidateRequest

            unquote(verified_routes())
          end
        end
      end

  Finally, request body validation will only work if the body is fetched from
  the conn. This is generally done by the `Plug.Parsers` plug. It can also be
  done by a custom plug if you are implementing an API that is working with
  plaintext or custom formats.

  ## Request validation

  Requests will be validated according to the request body schemas and parameter
  schemas defined in operations. The data will also be cast to the expected
  types:

  * Parameters whose schemas define a `type` of `boolean` or `integer` will be
    cast to that type. Arrays of such types are supported as well.
  * Parameters with type `string` and a `format` supported by `JSV` will be also
    cast according to that format. Output values for formats are described in
    the [JSV
    documentation](https://hexdocs.pm/jsv/validation-basics.html#formats). This
    includes, URI, Date, DateTime and Duration.
  * Request bodies are cast to their given schema too. When using raw schemas
    defined as maps, the main changes to the data is the cast of formats, just
    as for parameters. When schemas are defined using module names, and when
    those modules' structs are created with `JSV.defschema/1`, the request
    bodies will be cast to those structs.

  Request bodies will be validated according to the expected operation
  content-types, and the actual content-type of the request.

  ## Options

  * `:query_reader_opts` - If a Plug.Conn struct enters this plug without its
    query parameters being fetched, this plug will fetch them automatically
    using `Conn.fetch_query_params(conn, query_reader_opts)`. The default value
    is `#{inspect(@default_query_reader_opts)}`.
  * `:error_handler` - A module or `{module, argument}` tuple. The error handler
    must implement the `#{inspect(Oaskit.ErrorHandler)}` behaviour. It will be
    called on validation errors. Defaults to `Oaskit.ErrorHandler.Default`.
  * `:pretty_errors` - A boolean to control pretty printing of JSON errors
    payload in error handlers. Defaults to `true` when `Mix.env() != :prod`,
    defaults to `false` otherwise.
  * `:html_errors` - A boolean to control whether the default error handler is
    allowed to return HTML errors when the request accepts HTML. This is useful
    to quickly read errors when opening an url directly from the browser.
    Defaults to `true`.
  * Unknown options are collected and passed to the error handler.

  ## Non-required bodies

  A request body is considered empty if `""`, `nil` or an empty map (`%{}`). In
  that case, if the operation defines the request body with `required: false`
  (which is the default value!), the body validation will be skipped.

  The empty map is a special case because `Plug.Parsers` implementations cannot
  return anything else than a map. If a client sends an HTTP request with an
  `"application/json"` content-type but no body, the JSON parser in the Plug
  library will still return an empty map.

  To avoid problems, always define request bodies as required if you can. This
  is made automatically when using the "definition shortcuts" described in
  `#{inspect(Oaskit.Controller)}.operation/2`.

  ## Error handling

  Validation can fail at various steps:

  * Parameters validation
  * Content-type matching
  * Body validation

  On failure, the validation stops immediately. If a parameter is invalid, the
  body is not validated and the error handler is called with a single category
  of errors. In the case of parameters, multiple errors can be passed to the
  handler if multiple parameters are invalid or missing.

  Custom error handlers must implement the `Oaskit.ErrorHandler` behaviour and
  be ready to accept all error reasons that this plug can generate. Such reasons
  are described in the `t:Oaskit.ErrorHandler.reason/0` type.

  The 3rd argment passed to the `c:Oaskit.ErrorHandler.handle_error/3` depends
  on the `:error_handler` function. When defined as a module, the argument is
  all the other options given to this plug:

      plug Oaskit.Plugs.ValidateRequest,
        error_handler: MyErrorHandler,
        pretty_errors: true,
        custom_opt: "foo"

  This will allow the handler to receive `:pretty_errors`, `:custom_opt` and
  other options with default values.

  When passing a tuple, the second element will be passed as-is:

      plug Oaskit.Plugs.ValidateRequest,
        error_handler: {MyErrorHandler, "foo"}

  In the example above, the error handler will only receive `"foo"` as the 3rd
  argument of `c:Oaskit.ErrorHandler.handle_error/3`.
  """

  @behaviour Plug

  @impl true
  def init(opts) do
    {raw_error_handler, opts_no_handler} =
      opts
      |> Keyword.put_new(:query_reader_opts, @default_query_reader_opts)
      |> Keyword.put_new(:security, nil)
      |> Keyword.put_new_lazy(:pretty_errors, fn ->
        # Default to true only when mix is available:
        # * in dev/test environment.
        # * when compiling releases with phoenix set to compile-time. In that
        #   case we do not want pretty errors by default in production.
        function_exported?(Mix, :env, 0) && Mix.env() != :prod
      end)
      |> Keyword.put_new(:html_errors, true)
      |> Keyword.update(:security, nil, &cast_security/1)
      |> Keyword.pop(:error_handler, Oaskit.ErrorHandler.Default)

    error_handler =
      case raw_error_handler do
        mod when is_atom(mod) -> {mod, opts_no_handler}
        {mod, arg} when is_atom(mod) -> {mod, arg}
      end

    opts_no_handler
    |> Keyword.put(:error_handler, error_handler)
    |> Map.new()
  end

  defp cast_security(security) do
    case security do
      nil ->
        nil

      false ->
        false

      module when is_atom(module) ->
        {module, []}

      {module, opts} when is_atom(module) and is_list(opts) ->
        {module, opts}

      other ->
        raise inspect(__MODULE__) <>
                " only accepts `nil`, `module` or `{module, opts}` when `opts` is a keyword" <>
                " list as the `:security` option, got: " <>
                inspect(other)
    end
  end

  @impl true
  @spec call(Plug.Conn.t(), map) :: Plug.Conn.t() | no_return
  def call(conn, opts) do
    conn = ensure_query_params(conn, opts)
    {controller, action} = fetch_phoenix!(conn)

    case fetch_operation_id(conn, controller, action) do
      {:ok, operation_id} ->
        check_security_and_validate(conn, operation_id, opts)

      :ignore ->
        conn

      :__undef__ ->
        warn_undef_action(controller, action, conn.method)
        conn
    end
  end

  defp check_security_and_validate(conn, operation_id, opts) do
    spec_module = SpecProvider.fetch_spec_module!(conn)
    {op_map, _} = built_spec = Oaskit.build_spec!(spec_module)

    with {:ok, security} <- fetch_security(op_map, operation_id),
         %Plug.Conn{halted: false} <- apply_security(conn, security, operation_id, opts) do
      do_validate(conn, built_spec, operation_id, opts)
    else
      {:error, {:not_built, _}} = err -> err
      %Plug.Conn{halted: true} = conn -> conn
    end
  end

  defp do_validate(conn, built_spec, operation_id, opts) do
    request_data = RequestData.from_conn(conn)

    case RequestValidator.validate_request(request_data, built_spec, operation_id) do
      {:ok, private} ->
        Conn.put_private(conn, :oaskit, Map.merge(conn.private.oaskit, private))

      {:error, reason} ->
        conn
        |> Conn.put_private(
          :oaskit,
          Map.merge(conn.private.oaskit, %{operation_id: operation_id})
        )
        |> on_error(reason, opts)
    end
  end

  defp fetch_security(op_map, operation_id) do
    case op_map do
      %{^operation_id => %{security: security}} -> {:ok, security}
      _ -> {:error, {:not_built, operation_id}}
    end
  end

  defp apply_security(conn, [], _operation_id, _opts) do
    conn
  end

  defp apply_security(conn, nil, _operation_id, _opts) do
    conn
  end

  defp apply_security(conn, security, operation_id, opts) do
    case opts.security do
      nil ->
        warn_undef_security(conn, operation_id)

        conn
        |> Conn.send_resp(401, "unauthorized")
        |> Conn.halt()

      false ->
        conn

      {module, opts} when is_atom(module) ->
        opts = Keyword.merge(opts, security: security, operation_id: operation_id)
        module.call(conn, module.init(opts))
    end
  end

  defp on_error(conn, reason, opts) do
    case reason do
      {:parameters_errors, errors} when is_list(errors) ->
        call_error_handler(conn, reason, opts.error_handler)

      %InvalidBodyError{} ->
        call_error_handler(conn, reason, opts.error_handler)

      %UnsupportedMediaTypeError{} ->
        call_error_handler(conn, reason, opts.error_handler)

      {:not_built, operation_id} ->
        raise "operation with id #{inspect(operation_id)} was not built"
    end
  end

  defp ensure_query_params(conn, opts) do
    # If already fetched this is idempotent
    Conn.fetch_query_params(conn, opts.query_reader_opts)
  end

  defp fetch_phoenix!(conn) do
    case conn do
      %{private: %{phoenix_controller: controller, phoenix_action: action}} ->
        {controller, action}

      _ ->
        raise """
        conn given to #{inspect(__MODULE__)} was not routed by phoenix

        Make sure to call this plug from a phoenix controller.
        """
    end
  end

  defp fetch_operation_id(conn, controller, action) do
    hook(controller, :operation_id, action, method_to_verb(conn.method))
  end

  defp call_error_handler(conn, reason, {handler_mod, handler_arg}) do
    handler_mod.handle_error(conn, reason, handler_arg)
  end

  defp warn_undef_action(controller, action, method) do
    IO.warn("""
    Controller #{inspect(controller)} has no operation defined for action #{inspect(action)} with method #{inspect(method_to_verb(method))}

    Pass `false` to the `operation` macro to suppress this warning:

        operation #{inspect(action)}, false

        def #{action}(conn, params) do
          # ...
        end
    """)
  end

  defp warn_undef_security(conn, operation_id) do
    {controller, action} = fetch_phoenix!(conn)

    IO.warn("""
    Controller #{inspect(controller)} has security defined for operation #{operation_id} on action #{inspect(action)}
    but no security option is defined on the #{inspect(__MODULE__)} plug.

    Provide a custom security plug to the Oaskit.Plugs.ValidateRequest plug:

        plug Oaskit.Plugs.ValidateRequest, security: MyApp.Plugs.ApiSecurity

    Alternatively, pass `false` on this option to disable security checks:

        plug Oaskit.Plugs.ValidateRequest, security: false
    """)
  end

  defp hook(controller, kind, action, arg) do
    controller.__oaskit__(kind, action, arg)
  end

  Enum.each(Oaskit.Spec.PathItem.verbs(), fn verb ->
    method = verb |> Atom.to_string() |> String.upcase()

    defp method_to_verb(unquote(method)) do
      unquote(verb)
    end
  end)

  defp method_to_verb(_) do
    :unknown
  end
end
