defmodule OpenApify.Web.ResponseTest do
  alias OpenApify.TestWeb.PathsApiSpec
  import OpenApify.Test
  use OpenApify.ConnCase, async: true

  describe "with generated api" do
    test "response without defined operation", %{conn: conn} do
      conn = get(conn, ~p"/generated/resp/fortune-200-no-operation")

      assert_raise RuntimeError,
                   ~r/the connection was not validated by OpenApify.Plugs.ValidateRequest/,
                   fn ->
                     valid_response(PathsApiSpec, conn, 200)
                   end

      # status is checked
      assert_raise RuntimeError, ~r/expected response with status 999/, fn ->
        valid_response(PathsApiSpec, conn, 999)
      end
    end

    test "responses can be validated", %{conn: conn} do
      conn = get(conn, ~p"/generated/resp/fortune-200-valid")
      assert %{"message" => _, "category" => _} = valid_response(PathsApiSpec, conn, 200)
    end

    test "expecting another status", %{conn: conn} do
      # here we just delegate to Phoenix.Conntest
      conn = get(conn, ~p"/generated/resp/fortune-200-valid")

      assert_raise RuntimeError, ~r{expected response with status 201, got: 200}, fn ->
        valid_response(PathsApiSpec, conn, 201)
      end
    end

    test "response can be invalidated", %{conn: conn} do
      conn = get(conn, ~p"/generated/resp/fortune-200-invalid")

      assert_raise RuntimeError, ~r/invalid response returned by operation/, fn ->
        valid_response(PathsApiSpec, conn, 200)
      end
    end

    test "response without defined response bodies", %{conn: conn} do
      conn = get(conn, ~p"/generated/resp/fortune-200-no-content-def")
      "anything" = valid_response(PathsApiSpec, conn, 200)

      # despite the missing content validation, status is checked
      assert_raise RuntimeError, ~r/expected response with status 999/, fn ->
        valid_response(PathsApiSpec, conn, 999)
      end
    end

    test "response with other content type", %{conn: conn} do
      conn = get(conn, ~p"/generated/resp/fortune-200-bad-content-type")

      assert_raise RuntimeError, ~r/has no definition for content-type/, fn ->
        valid_response(PathsApiSpec, conn, 200)
      end
    end

    test "using default response for unspecified status", %{conn: conn} do
      conn = get(conn, ~p"/generated/resp/fortune-500-default-resp")
      valid_response(PathsApiSpec, conn, 500)
    end

    test "default response with invalid content", %{conn: conn} do
      conn = get(conn, ~p"/generated/resp/fortune-500-bad-default-resp")

      assert_raise RuntimeError, ~r{invalid response}, fn ->
        valid_response(PathsApiSpec, conn, 500)
      end
    end
  end
end
