defmodule Oaskit.Validation.RequestValidator do
  alias Oaskit.Errors.InvalidBodyError
  alias Oaskit.Errors.InvalidParameterError
  alias Oaskit.Errors.MissingParameterError
  alias Oaskit.Errors.UnsupportedMediaTypeError
  alias Oaskit.Plugs.ValidateRequest
  alias Oaskit.Validation.RequestData
  alias Plug.Conn

  @moduledoc """
  Base validation logic for requests, used by the `#{inspect(ValidateRequest)}`
  Plug.

  This module validates a `#{inspect(RequestData)}` struct instead of a
  `#{inspect(Plug.Conn)}` struct, which makes it usable from client libraries.
  """

  @type private_data :: %{
          body_params: map,
          query_params: map,
          path_params: map,
          operation_id: binary
        }

  @type validation_error ::
          InvalidBodyError.t()
          | UnsupportedMediaTypeError.t()
          | {:parameters_errors, [InvalidParameterError.t() | MissingParameterError.t()]}
          | {:not_built, operation_id :: binary}

  @type built_spec :: {%{binary => %{security: term, validation: term}}, jsv_ctx :: term}

  @doc """
  Validates a request and returns cast data (body params, query params and path
  params) or an error.
  """
  @spec validate_request(RequestData.t(), module | built_spec, binary) ::
          {:ok, private_data} | {:error, validation_error}
  def validate_request(%RequestData{} = req_data, spec_module, operation_id)
      when is_atom(spec_module) do
    validate_request(req_data, Oaskit.build_spec!(spec_module), operation_id)
  end

  def validate_request(%RequestData{} = req_data, {_, _} = built_spec, operation_id) do
    case fetch_validations(built_spec, operation_id) do
      {:ok, validations_with_root} ->
        run_validations(req_data, validations_with_root, operation_id)

      {:error, _} = err ->
        err
    end
  end

  defp fetch_validations({op_map, jsv_root}, operation_id) do
    case op_map do
      %{^operation_id => %{validation: op_validations}} -> {:ok, {op_validations, jsv_root}}
      _ -> {:error, {:not_built, operation_id}}
    end
  end

  defp run_validations(req_data, {validations, jsv_root}, operation_id) do
    private_accin = %{
      body_params: %{},
      query_params: %{},
      path_params: %{},
      operation_id: operation_id
    }

    Enum.reduce_while(validations, {:ok, private_accin}, fn
      validation, {:ok, private} ->
        # we are not collecting all errors but rather stop on the first error. If
        # parameters are wrong, as they handle path parameters we act as if the
        # route is wrong, and do not want to validate the body.
        case validate(req_data, validation, jsv_root) do
          {:ok, more_private} -> {:cont, {:ok, Map.merge(private, more_private)}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  defp validate(req_data, {:parameters, by_location}, jsv_root) do
    validate_parameters(req_data, by_location, jsv_root)
  end

  defp validate(req_data, {:body, required?, media_matchers}, jsv_root) do
    validate_body(req_data, req_data.body_params, required?, media_matchers, jsv_root)
  end

  defp validate_parameters(req_data, by_location, jsv_root) do
    %{path_params: raw_path_params, query_params: raw_query_params} = req_data
    %{path: path_specs, query: query_specs} = by_location

    {cast_path_params, path_errors} =
      validate_parameters_group(path_specs, raw_path_params, jsv_root)

    {cast_query_params, query_errors} =
      validate_parameters_group(query_specs, raw_query_params, jsv_root)

    case {path_errors, query_errors} do
      {[], []} ->
        private = %{path_params: cast_path_params, query_params: cast_query_params}
        {:ok, private}

      _ ->
        {:error, {:parameters_errors, path_errors ++ query_errors}}
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

  defp validate_body(_req_data, body, false = _required?, _, _)
       when body in [nil, ""]
       when map_size(body) == 0 do
    {:ok, %{body_params: nil}}
  end

  defp validate_body(req_data, body, _required?, media_matchers, jsv_root) do
    {primary, secondary} = fetch_content_type(req_data)

    with {:ok, {_, jsv_key}} <- match_media_type(media_matchers, {primary, secondary}),
         :ok <- ensure_fetched_body!(body),
         {:ok, cast_body} <- validate_with_schema(body, jsv_key, jsv_root) do
      {:ok, %{body_params: cast_body}}
    else
      {:error, %JSV.ValidationError{} = validation_error} ->
        {:error, %InvalidBodyError{validation_error: validation_error, value: body}}

      {:error, :media_type_match} ->
        {:error, %UnsupportedMediaTypeError{media_type: "#{primary}/#{secondary}", value: body}}
    end
  end

  defp fetch_content_type(%RequestData{} = req_data) do
    %{req_headers: req_headers} = req_data

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
    # Precast value never fails. When we cannot precast a value we still call
    # the user provided schema, which will give more meaningful errors ; and a
    # schema pointer for the invalidating schema, which gives better debugging.
    #
    # if we have an un-exploded list parameter like `a=1,not_int,3` and the
    # schema expects an array of integers, there is no right way to fail:
    #
    # * fail the precast entirely and pass the string "1,not_int,3" to the
    #   schema. Looks strange because the params describe an array with explode
    #   false, so Oaskit should always split here.
    # * split the list but fail to precast items, giving ["1","not_int","3"]. In
    #   that case the schema error will return 3 items errors for "expected an
    #   integer and got a string". It's bad because again the query string is
    #   always a string, Oaskit should cast both numeric strings to integer.
    #
    # So what we do is never fail:
    #
    # If we want to reach the schema validator, we can only pass
    # [1,"not_int",3], which is mixing successful items and bad items.
    #
    # So yeah failed precast will just return the previous values. If someday we
    # need to pipe precasts we will just stop the pipe if we get an error and
    # return whatever value we casted before that error.
    precast_value = precast_parameter(value, caster)

    validate_with_schema(precast_value, jsv_key, jsv_root)
  end

  defp validate_with_schema(value, jsv_key, jsv_root) do
    JSV.validate(value, jsv_root, cast: true, cast_formats: true, key: jsv_key)
  end

  # precast_parameter / precast_array - returns a value
  # apply_precast - returns a result tuple

  defp precast_parameter(value, [h | t]) do
    case apply_precast(value, h) do
      {:ok, value} -> precast_parameter(value, t)
      {:error, _reason} -> value
    end
  end

  defp precast_parameter(value, []) do
    value
  end

  # When dealing with arrays we want to return
  defp precast_array([h | t], fun, acc) do
    case fun.(h) do
      {:ok, new_h} -> precast_array(t, fun, [new_h | acc])
      {:error, _} -> precast_array(t, fun, [h | acc])
    end
  end

  defp precast_array([], _, acc) do
    :lists.reverse(acc)
  end

  defp apply_precast(value, fun) when is_function(fun, 1) do
    case fun.(value) do
      {:ok, value} -> {:ok, value}
      {:error, _} = err -> err
    end
  end

  defp apply_precast(values, {:array, fun}) when is_list(values) and is_function(fun, 1) do
    {:ok, precast_array(values, fun, [])}
  end

  defp apply_precast(_values, {:array, fun}) when is_function(fun, 1) do
    {:error, :non_array_parameter}
  end

  # TODO here we could support having a pre-existing list in query parameters,
  # since what we want with the split is a list anyway.
  defp apply_precast(value, {:split, splitter}) when is_binary(value) do
    {:ok, String.split(value, splitter)}
  end

  defp apply_precast(_value, _) do
    {:error, :non_string_parameter}
  end
end
