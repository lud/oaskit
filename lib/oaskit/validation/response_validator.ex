defmodule Oaskit.Validation.ResponseValidator do
  alias Oaskit.Validation.RequestValidator
  alias Oaskit.Validation.ResponseData

  @moduledoc """
  Base validation logic for responses, used by the `#{inspect(Oaskit.Test)}`
  helper.
  """

  @spec validate_response(ResponseData.t(), module, binary) ::
          {:ok, term} | {:error, JSV.ValidationError.t()}
  def validate_response(resp_data, spec_module, operation_id) do
    {built, jsv_root} = Oaskit.build_spec!(spec_module, responses: true)

    %{status: status, resp_body: resp_body} = resp_data

    content_validation =
      with {:ok, %{validation: path_validations}} <- Map.fetch(built, operation_id),
           {:ok, responses} <- Keyword.fetch(path_validations, :responses),
           {:ok, status_validations} <- fetch_response_spec(responses, status) do
        status_validations
      else
        _ ->
          raise "could not find response definition for operation #{inspect(operation_id)} " <>
                  "with status #{inspect(status)}"
      end

    case content_validation do
      :no_validation ->
        {:ok, :no_validation}

      media_types when is_list(media_types) ->
        content_type = content_type(resp_data)

        ctx = %{
          content_validation: media_types,
          type_subtype: parse_content_type(content_type),
          content_type: content_type,
          body: resp_body,
          operation_id: operation_id,
          status: status,
          jsv_root: jsv_root
        }

        do_validate_response(ctx)
    end
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
