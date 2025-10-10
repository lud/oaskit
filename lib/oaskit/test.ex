defmodule Oaskit.Test do
  alias Oaskit.Validation.ResponseData
  alias Oaskit.Validation.ResponseValidator
  alias Plug.Conn

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
    body = phoenix_response(conn, status)
    operation_id = fetch_operation_id(conn)
    content_type = ResponseValidator.content_type(conn)
    body = maybe_parse_body(body, ResponseValidator.parse_content_type(content_type))
    resp_data = %ResponseData{resp_body: body, resp_headers: conn.resp_headers, status: status}

    case ResponseValidator.validate_response(resp_data, spec_module, operation_id) do
      {:ok, _} ->
        # We do not return the cast body because in test we validate the
        # behaviour of the app from an external point of view.
        body

      {:error, jsv_error} ->
        raise "invalid response returned by operation #{inspect(operation_id)} " <>
                "with status #{inspect(status)} and content-type #{inspect(content_type)}" <>
                """

                #{Exception.message(jsv_error)}

                Response data:

                #{inspect(body, pretty: true)}
                """
    end
  end

  # Copy from phoenix to not depend on phoenix
  def phoenix_response(%Conn{state: :unset}, _status) do
    raise """
    expected connection to have a response but no response was set/sent.
    Please verify that you assign to "conn" after a request:

        conn = get(conn, "/")
        assert %{"data" => "foo"} = valid_response(Spec, conn, 200)
    """
  end

  def phoenix_response(%Conn{status: status, resp_body: body}, given) do
    given = Conn.Status.code(given)

    if given == status do
      body
    else
      body_debug = format_error_body(body)

      raise "expected response with status #{given}, got: #{status}, with body:\n#{body_debug}"
    end
  end

  defp format_error_body(body) do
    if is_binary(body) do
      body
    else
      inspect(body)
    end
  end

  defp fetch_operation_id(conn) do
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
  end

  defp maybe_parse_body(body, {_, subtype}) do
    # For now we only know how to parse JSON
    cond do
      subtype == "json" -> json_decode!(body)
      String.ends_with?(subtype, "+json") -> json_decode!(body)
      :otherwise -> body
    end
  end

  defp json_decode!(data) do
    data = IO.iodata_to_binary(data)

    case data do
      "" -> ""
      payload -> JSV.Codec.decode!(payload)
    end
  end
end
