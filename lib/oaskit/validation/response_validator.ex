defmodule Oaskit.Validation.ResponseValidator do
  alias Oaskit.Validation.RequestValidator
  alias Oaskit.Validation.ResponseData

  @moduledoc """
  Base validation logic for responses, used by the `#{inspect(Oaskit.Test)}`
  helper.
  """

  @spec validate_response(ResponseData.t(), module, binary) ::
          {:ok, term}
          | {:error, JSV.ValidationError.t()}
          | {:error, {:response_headers_errors, [term]}}
  def validate_response(resp_data, spec_module, operation_id) do
    {built, jsv_root} = Oaskit.build_spec!(spec_module, responses: true)

    %{status: status} = resp_data

    response_validation =
      with {:ok, %{validation: path_validations}} <- Map.fetch(built, operation_id),
           {:ok, responses} <- Keyword.fetch(path_validations, :responses),
           {:ok, status_validations} <- fetch_response_spec(responses, status) do
        status_validations
      else
        _ ->
          raise "could not find response definition for operation #{inspect(operation_id)} " <>
                  "with status #{inspect(status)}"
      end

    %{body: body_validation, headers: header_validations} = response_validation

    with :ok <- validate_response_headers(header_validations, resp_data, jsv_root) do
      validate_response_body(body_validation, resp_data, operation_id, status, jsv_root)
    end
  end

  defp validate_response_body(:no_validation, _resp_data, _operation_id, _status, _jsv_root) do
    {:ok, :no_validation}
  end

  defp validate_response_body(media_types, resp_data, operation_id, status, jsv_root)
       when is_list(media_types) do
    content_type = content_type(resp_data)

    ctx = %{
      content_validation: media_types,
      type_subtype: parse_content_type(content_type),
      content_type: content_type,
      body: resp_data.resp_body,
      operation_id: operation_id,
      status: status,
      jsv_root: jsv_root
    }

    do_validate_response(ctx)
  end

  defp validate_response_headers([], _resp_data, _jsv_root) do
    :ok
  end

  defp validate_response_headers(header_validations, resp_data, jsv_root) do
    raw = response_headers_map(resp_data)

    errors =
      Enum.reduce(header_validations, [], fn header, errors ->
        validate_response_header(header, raw, jsv_root, errors)
      end)

    case errors do
      [] -> :ok
      _ -> {:error, {:response_headers_errors, :lists.reverse(errors)}}
    end
  end

  defp validate_response_header(header, raw, jsv_root, errors) do
    %{
      name: name,
      ext_name: ext_name,
      required: required?,
      precast: precast,
      schema_key: schema_key
    } = header

    case Map.fetch(raw, name) do
      {:ok, value} ->
        value = RequestValidator.cast_param_value(value, precast)

        case RequestValidator.validate_param_value(value, schema_key, jsv_root) do
          {:ok, _cast_value} -> errors
          {:error, validation_error} -> [{:invalid, ext_name, value, validation_error} | errors]
        end

      :error when required? ->
        [{:missing, ext_name} | errors]

      :error ->
        errors
    end
  end

  # conn.resp_headers is a list of {name, value} tuples; names are lowercase. We
  # keep the first value seen for each header name.
  defp response_headers_map(resp_data) do
    Enum.reduce(resp_data.resp_headers, %{}, fn {k, v}, acc ->
      Map.put_new(acc, String.downcase(k), v)
    end)
  end

  defp fetch_response_spec(responses, status) do
    case responses do
      %{^status => resp} -> {:ok, resp}
      %{:default => resp} -> {:ok, resp}
      _ -> :error
    end
  end

  @doc false
  def content_type(resp_data) do
    case get_resp_header(resp_data, "content-type") do
      [] ->
        raise "missing response content-type header"

      [raw] ->
        case Texture.HttpStructuredField.parse_item(raw, unwrap: true, maps: true) do
          {:ok, {token, _}} -> token
          _ -> raise "invalid content-type header: #{inspect(raw)}"
        end

      [_ | _] ->
        raise "multiple content-type header values"
    end
  end

  @doc false
  def parse_content_type(content_type) do
    case Plug.Conn.Utils.content_type(content_type) do
      :error -> {content_type, ""}
      {:ok, primary, secondary, _params} -> {primary, secondary}
    end
  end

  defp get_resp_header(req_data, key) do
    for {^key, value} <- req_data.resp_headers do
      value
    end
  end

  defp do_validate_response(ctx) do
    case match_media_type(ctx) do
      :no_validation -> {:ok, ctx.body}
      jsv_key -> validate_body(ctx.body, jsv_key, ctx)
    end
  end

  defp match_media_type(ctx) do
    case RequestValidator.match_media_type(ctx.content_validation, ctx.type_subtype) do
      {:ok, {_ct, jsv_key}} ->
        jsv_key

      {:error, :media_type_match} ->
        raise "operation #{inspect(ctx.operation_id)} " <>
                "with status #{inspect(ctx.status)} has no definition for content-type #{inspect(ctx.content_type)}"
    end
  end

  defp validate_body(body, jsv_key, ctx) do
    JSV.validate(body, ctx.jsv_root, key: jsv_key)
  end
end
