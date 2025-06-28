defmodule OpenApify.Plugs.ValidateRequest do
  alias OpenApify.Errors.InvalidBodyError
  alias OpenApify.Errors.InvalidParameterError
  alias OpenApify.Errors.MissingParameterError
  alias OpenApify.Errors.UnsupportedMediaTypeError
  alias Plug.Conn
  require Logger

  @moduledoc """
  This plug will match incoming requests to operations defined with the
  `#{inspect(OpenApify.Controller)}.operation/2` or
  `#{inspect(OpenApify.Controller)}.use_operation/2` macros and retrieved from a
  provided OpenAPI Specification module.

  ## Pluggin' in

  To use this plug in a controller, the
  `#{inspect(OpenApify.Plugs.SpecProvider)}` plug must be used in the router for
  the corresponding routes.

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        pipeline :api do
          plug OpenApify.Plugs.SpecProvider, spec: MyAppWeb.OpenAPISpec
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
  OpenApify.Controller`.

      defmodule MyAppWeb do
        def controller do
          # ...
        end

        def api_controller do
          quote do
            use Phoenix.Controller, formats: [:json], layouts: []

            # Use the controller helpers to define operations
            use OpenApify.Controller

            use Gettext, backend: MyAppWeb.Gettext
            import Plug.Conn

            # Use the plug here. This has to be after `use Phoenix.Controller`.
            plug OpenApify.Plugs.ValidateRequest

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
    is `[length: 1_000_000, validate_utf8: true]`.
  * `:error_handler` - A module or `{module, argument}` tuple. The error handler
    must implement the `#{inspect(OpenApify.ErrorHandler)}` behaviour. It will be
    called on validation errors. Defaults to `OpenApify.ErrorHandler.Default`.
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
  `#{inspect(OpenApify.Controller)}.operation/2`.

  ## Error handling

  Validation can fail at various steps:

  * Parameters validation
  * Content-type matching
  * Body validation

  On failure, the validation stops immediately. If a parameter is invalid, the
  body is not validated and the error handler is called with a single category
  of errors. In the case of parameters, multiple errors can be passed to the
  handler if multiple parameters are invalid or missing.

  Custom error handlers must implement the `OpenApify.ErrorHandler` behaviour and
  be ready to accept all error reasons that this plug can generate. Such reasons
  are described in the `t:OpenApify.ErrorHandler.reason/0` type.

  The 3rd argment passed to the `c:OpenApify.ErrorHandler.handle_error/3` depends
  on the `:error_handler` function. When defined as a module, the argument is
  all the other options given to this plug:

      plug OpenApify.Plugs.ValidateRequest,
        error_handler: MyErrorHandler,
        pretty_errors: true,
        custom_opt: "foo"

  This will allow the handler to receive `:pretty_errors`, `:custom_opt` and
  other options with default values.

  When passing a tuple, the second element will be passed as-is:

      plug OpenApify.Plugs.ValidateRequest,
        error_handler: {MyErrorHandler, "foo"}

  In the example above, the error handler will only receive `"foo"` as the 3rd
  argument of `c:OpenApify.ErrorHandler.handle_error/3`.
  """

  @behaviour Plug

  @impl true
  def init(opts) do
    query_reader_opts = Keyword.get(opts, :query_reader, length: 1_000_000, validate_utf8: true)

    opts =
      opts
      |> Keyword.put_new_lazy(:pretty_errors, fn ->
        # Default to true only when mix is available:
        # * in dev/test environment.
        # * when compiling releases with phoenix set to compile-time. In that
        #   case we do not want pretty errors by default in production.
        function_exported?(Mix, :env, 0) && Mix.env() != :prod
      end)
      |> Keyword.put_new(:html_errors, true)

    {handler, opts_no_handler} = Keyword.pop(opts, :error_handler, OpenApify.ErrorHandler.Default)

    error_handler =
      case handler do
        mod when is_atom(mod) -> {mod, opts_no_handler}
        {mod, arg} when is_atom(mod) -> {mod, arg}
      end

    %{
      error_handler: error_handler,
      query_reader_opts: query_reader_opts
    }
  end

  @impl true
  def call(conn, opts) do
    conn = ensure_query_params(conn, opts)
    {controller, action} = fetch_phoenix!(conn)

    with {:ok, operation_id} <- fetch_operation_id(conn, controller, action),
         conn1 = merge_private(conn, :operation_id, operation_id),
         {:ok, validations_with_root} <- fetch_validations(conn1, operation_id),
         {:ok, private, conn1} <- run_validations(conn1, validations_with_root) do
      merge_private(conn1, private)
    else
      {:error, {:parameters_errors, errors} = reason, next_conn} when is_list(errors) ->
        call_error_handler(next_conn, reason, opts.error_handler)

      {:error, %InvalidBodyError{} = reason, next_conn} ->
        call_error_handler(next_conn, reason, opts.error_handler)

      {:error, %UnsupportedMediaTypeError{} = reason, next_conn} ->
        call_error_handler(next_conn, reason, opts.error_handler)

      {:error, {:not_built, operation_id}, _next_conn} ->
        raise "operation with id #{inspect(operation_id)} was not built"

      {:skip, _} ->
        conn
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

  defp fetch_validations(conn, operation_id) do
    spec_module = fetch_spec_module!(conn)
    {validations, jsv_root} = OpenApify.build_spec!(spec_module)

    case validations do
      %{^operation_id => op_validations} -> {:ok, {op_validations, jsv_root}}
      _ -> {:error, {:not_built, operation_id}, conn}
    end
  end

  defp fetch_operation_id(conn, controller, action) do
    case hook(controller, :operation_id, action, method_to_verb(conn.method)) do
      {:ok, operation_id} ->
        {:ok, operation_id}

      :ignore ->
        {:skip, :unhandled_action}

      :__undef__ ->
        warn_undef_action(controller, action, conn.method)
        {:skip, :unhandled_action}
    end
  end

  defp fetch_spec_module!(conn) do
    case conn do
      %{private: %{open_apify: %{spec: module}}} ->
        module

      _ ->
        raise """
        #{inspect(__MODULE__)} was called but #{inspect(OpenApify.Plugs.SpecProvider)} was not called upstream

        Make sure to provide a spec module before calling #{inspect(__MODULE__)}:

        pipeline :api do
          plug OpenApify.Plugs.SpecProvider, spec: OpenApify.TestWeb.PathsApiSpec
        end

        scope "/api", MyAppWeb.Api do
          pipe_through :api

          get "/hello", HelloController, :hello
        end
        """
    end
  end

  defp run_validations(conn, {validations, jsv_root}) do
    empty_params = %{body_params: %{}, query_params: %{}, path_params: %{}}

    Enum.reduce_while(validations, {:ok, empty_params, conn}, fn
      validation, {:ok, private, conn} ->
        # we are not collecting all errors but rather stop on the first error. If
        # parameters are wrong, as they handle path parameters we act as if the
        # route is wrong, and do not want to validate the body.
        case validate(conn, validation, jsv_root) do
          {:ok, new_private, conn} -> {:cont, {:ok, Map.merge(private, new_private), conn}}
          {:error, reason, conn} -> {:halt, {:error, reason, conn}}
        end
    end)
  end

  defp validate(conn, {:parameters, by_location}, jsv_root) do
    validate_parameters(conn, by_location, jsv_root)
  end

  defp validate(conn, {:body, required?, media_matchers}, jsv_root) do
    validate_body(conn, conn.body_params, required?, media_matchers, jsv_root)
  end

  defp validate_parameters(conn, by_location, jsv_root) do
    %{path_params: raw_path_params, query_params: raw_query_params} = conn
    %{path: path_specs, query: query_specs} = by_location

    {cast_path_params, path_errors} =
      validate_parameters_group(path_specs, raw_path_params, jsv_root)

    {cast_query_params, query_errors} =
      validate_parameters_group(query_specs, raw_query_params, jsv_root)

    case {path_errors, query_errors} do
      {[], []} ->
        private = %{path_params: cast_path_params, query_params: cast_query_params}
        {:ok, private, conn}

      _ ->
        {:error, {:parameters_errors, path_errors ++ query_errors}, conn}
    end
  end

  defp validate_parameters_group(param_specs, raw_params, jsv_root) do
    Enum.reduce(param_specs, {%{}, []}, fn parameter, {acc, errors} ->
      validate_parameter(parameter, raw_params, jsv_root, acc, errors)
    end)
  end

  defp validate_parameter(parameter, raw_params, jsv_root, acc, errors) do
    %{bin_key: bin_key, key: key, schema_key: jsv_key, required: required?} = parameter

    case Map.fetch(raw_params, bin_key) do
      {:ok, value} ->
        case validate_with_schema(value, jsv_key, jsv_root) do
          {:ok, cast_value} ->
            acc = Map.put(acc, key, cast_value)
            {acc, errors}

          {:error, validation_error} ->
            err = %InvalidParameterError{
              in: parameter.in,
              name: bin_key,
              value: value,
              validation_error: validation_error
            }

            {acc, [err | errors]}
        end

      :error when required? ->
        err = %MissingParameterError{in: parameter.in, name: bin_key}
        {acc, [err | errors]}

      :error ->
        {acc, errors}
    end
  end

  defp validate_body(conn, body, false = _required?, _, _)
       when body in [nil, ""]
       when map_size(body) == 0 do
    {:ok, %{body_params: nil}, conn}
  end

  defp validate_body(conn, body, _required?, media_matchers, jsv_root) do
    {primary, secondary} = fetch_content_type(conn)

    with {:ok, {_, jsv_key}} <- match_media_type(media_matchers, {primary, secondary}),
         :ok <- ensure_fetched_body!(body),
         {:ok, cast_body} <- validate_with_schema(body, jsv_key, jsv_root) do
      {:ok, %{body_params: cast_body}, conn}
    else
      {:error, %JSV.ValidationError{} = validation_error} ->
        {:error, %InvalidBodyError{validation_error: validation_error, value: body}, conn}

      {:error, :media_type_match} ->
        {:error, %UnsupportedMediaTypeError{media_type: "#{primary}/#{secondary}", value: body},
         conn}
    end
  end

  defp fetch_content_type(conn) do
    %{req_headers: req_headers} = conn

    case List.keyfind(req_headers, "content-type", 0, :error) do
      :error ->
        {"unknown", "unknown"}

      {"content-type", content_type} ->
        case Conn.Utils.content_type(content_type) do
          :error -> {content_type, ""}
          {:ok, primary, secondary, _params} -> {primary, secondary}
        end
    end
  end

  @doc false
  def match_media_type([{{primary, secondary}, _jsv_key} = matched | _], {primary, secondary}) do
    {:ok, matched}
  end

  def match_media_type([{{"*", _secondary}, _jsv_key} = matched | _], _) do
    {:ok, matched}
  end

  def match_media_type([{{primary, "*"}, _jsv_key} = matched | _], {primary, _}) do
    {:ok, matched}
  end

  def match_media_type([_ | matchspecs], content_type_tuple) do
    match_media_type(matchspecs, content_type_tuple)
  end

  def match_media_type([], _) do
    {:error, :media_type_match}
  end

  defp ensure_fetched_body!(body) do
    case body do
      %Plug.Conn.Unfetched{} ->
        raise ArgumentError,
              "body is not fetched, use plug parsers or a custom plug to fetch the body"

      _ ->
        :ok
    end
  end

  defp validate_with_schema(value, jsv_key, jsv_root)

  defp validate_with_schema(value, :no_validation, _) do
    {:ok, value}
  end

  defp validate_with_schema(value, {:precast, caster, jsv_key}, jsv_root) do
    case precast_parameter(value, caster) do
      {:ok, precast_value} ->
        validate_with_schema(precast_value, jsv_key, jsv_root)

      {:error, _} ->
        # On error we still call the real schema. For instance if "hello" is
        # given for the integer type, we will have a correct type error (though
        # the value will be quoted if shown in the error message)
        validate_with_schema(value, jsv_key, jsv_root)
    end
  end

  defp validate_with_schema(value, jsv_key, jsv_root) do
    JSV.validate(value, jsv_root, cast: true, cast_formats: true, key: jsv_key)
  end

  defp precast_parameter(value, fun) when is_function(fun, 1) do
    fun.(value)
  end

  defp precast_parameter(values, {:list, fun}) when is_list(values) and is_function(fun, 1) do
    precast_list(values, fun, [])
  end

  defp precast_parameter(_values, {:list, fun}) when is_function(fun, 1) do
    {:error, :non_array_parameter}
  end

  defp precast_list([h | t], fun, acc) do
    case fun.(h) do
      {:ok, v} -> precast_list(t, fun, [v | acc])
      {:error, _} = err -> err
    end
  end

  defp precast_list([], _, acc) do
    {:ok, :lists.reverse(acc)}
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

  defp hook(controller, kind, action, arg) do
    controller.__open_apify__(kind, action, arg)
  end

  defp merge_private(conn, key, value) do
    merge_private(conn, %{key => value})
  end

  defp merge_private(%Plug.Conn{private: %{open_apify: map} = private} = conn, new) do
    %{conn | private: %{private | open_apify: Map.merge(map, new)}}
  end

  defp merge_private(conn, new) do
    Plug.Conn.put_private(conn, :open_apify, new)
  end

  Enum.each(OpenApify.Spec.PathItem.verbs(), fn verb ->
    method = verb |> Atom.to_string() |> String.upcase()

    defp method_to_verb(unquote(method)) do
      unquote(verb)
    end
  end)

  defp method_to_verb(_) do
    :unknown
  end
end
