defmodule Oaskit.Test do
  alias Oaskit.Parsers.HttpStructuredField
  alias Oaskit.Plugs.ValidateRequest

  @moduledoc """
  Provides the `valid_response/3` test helper to validate API responses in your
  ExUnit tests.
  """

  @doc ~S"""
  Validates that the given conn bears a response that is valid with regard to
  the OpenAPI operation that served it, and returns the response body.

  Responses returned with a JSON based content-type like `"application/json"` or
  `"application/vnd.api+json"` will be decoded.

  It is encouraged to wrap this function with a custom helper, typically in your
  `MyAppWeb.ConnCase` test helper:

      defmodule MyAppWeb.ConnCase do

        # ...

        # You can wrap the helper function this way so you do not have to pass
        # The spec module in every call:
        def valid_response(conn, status) do
          Oaskit.Test.valid_response(MyAppWeb.OpenAPISpec, conn, status)
        end
      end


  Then use the helper in your tests:

      test "should return the user info", %{conn: conn} do
        %{id: id} = user_fixture(username: "joe", roles: ["admin"])
        conn = get(conn, ~p"/api/users/#{id}")

        assert %{
          "username" => "joe",
          "roles" => ["admin"]
        } = valid_response(conn, 200)
      end
  """
  def valid_response(spec_module, %Plug.Conn{} = conn, status) when is_integer(status) do
    body = Phoenix.ConnTest.response(conn, status)

    operation_id =
      case get_in(conn.private, [:oaskit, :operation_id]) do
        nil ->
          raise """
          the connection was not validated by Oaskit.Plugs.ValidateRequest

          This may happen if no pipeline with the Oaskit plugs is defined for
          the route, if the operation is not declared above the controller function
          or is explictitly disabled with `operation :my_function, false`.
          """

        opid ->
          opid
      end

    {validations, jsv_root} = Oaskit.build_spec!(spec_module, responses: true)

    content_validation =
      with {:ok, path_validations} <- Map.fetch(validations, operation_id),
           {:ok, responses} <- Keyword.fetch(path_validations, :responses),
           {:ok, status_validations} <- fetch_response(responses, status) do
        status_validations
      else
        _ ->
          raise "could not find response definition for operation #{inspect(operation_id)} " <>
                  "with status #{inspect(status)}"
      end

    case content_validation do
      :no_validation ->
        body

      list when is_list(list) ->
        content_type = content_type(conn)

        parse_validate_response(%{
          body: body,
          conn: conn,
          content_type: content_type,
          type_subtype: parse_content_type(content_type),
          content_validation: list,
          jsv_root: jsv_root,
          operation_id: operation_id,
          status: status
        })
    end
  end

  defp fetch_response(responses, status) do
    case responses do
      %{^status => resp} -> {:ok, resp}
      %{:default => resp} -> {:ok, resp}
      _ -> :error
    end
  end

  defp parse_validate_response(ctx) do
    body = maybe_parse_body(ctx)

    case match_media_type(ctx) do
      :no_validation -> body
      jsv_key -> validate_response(body, jsv_key, ctx)
    end
  end

  defp validate_response(body, jsv_key, ctx) do
    case JSV.validate(body, ctx.jsv_root, key: jsv_key) do
      {:ok, _} ->
        body

      {:error, jsv_error} ->
        raise "invalid response returned by operation #{inspect(ctx.operation_id)} " <>
                "with status #{inspect(ctx.status)} and content-type #{inspect(ctx.content_type)}" <>
                """


                #{Exception.message(jsv_error)}

                Response data:

                #{inspect(body, pretty: true)}
                """
    end
  end

  defp match_media_type(ctx) do
    type_subtype = parse_content_type(ctx.content_type)

    case ValidateRequest.match_media_type(ctx.content_validation, type_subtype) do
      {:ok, {_ct, jsv_key}} ->
        jsv_key

      {:error, :media_type_match} ->
        raise "operation #{inspect(ctx.operation_id)} " <>
                "with status #{inspect(ctx.status)} has no definition for content-type #{inspect(ctx.content_type)}"
    end
  end

  defp maybe_parse_body(ctx) do
    %{body: body, type_subtype: {_, subtype}} = ctx
    # For now we only know how to parse JSON
    cond do
      subtype == "json" -> json_decode!(body)
      String.ends_with?(subtype, "+json") -> json_decode!(body)
      :otherwise -> body
    end
  end

  defp json_decode!(data) do
    JSV.Codec.decode!(data)
  end

  defp content_type(conn) do
    case Plug.Conn.get_resp_header(conn, "content-type") do
      [] ->
        raise "missing response content-type header"

      [raw] ->
        case HttpStructuredField.parse_sf_item(raw, unwrap: true, maps: true) do
          {:ok, {token, _}} -> token
          _ -> raise "invalid content-type header: #{inspect(raw)}"
        end

      [_ | _] ->
        raise "multiple content-type header values"
    end
  end

  defp parse_content_type(content_type) do
    case Plug.Conn.Utils.content_type(content_type) do
      :error -> {content_type, ""}
      {:ok, primary, secondary, _params} -> {primary, secondary}
    end
  end
end
