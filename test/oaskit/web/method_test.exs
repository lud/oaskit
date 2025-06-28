defmodule Oaskit.Web.MethodTest do
  use Oaskit.ConnCase, async: true

  # The MethodController defines an operation for each method. The operation
  # name is "m#{method}".
  #
  # The lib should use the correct operation id as each one is given the
  # method to match with the `operation` macro.

  describe "matching method –" do
    Enum.each([:get, :put, :post, :delete, :options, :head, :patch, :trace], fn verb ->
      test verb, %{conn: conn} do
        verb = unquote(verb)
        method = verb |> Atom.to_string() |> String.upcase()
        expected_op_id = "m#{method}"

        conn =
          conn
          |> reply_with_oaskit_op_id(expected_op_id)
          |> Phoenix.ConnTest.dispatch(@endpoint, verb, ~p"/generated/method/p", nil)

        assert response(conn, 200)
      end
    end)
  end

  defp reply_with_oaskit_op_id(conn, expected_op_id) do
    with_response(conn, fn conn, _params ->
      assert %{operation_id: ^expected_op_id} = conn.private.oaskit
      send_resp(conn, 200, "")
    end)
  end
end
