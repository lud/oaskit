defmodule Oaskit.SpecControllerTest do
  use Oaskit.ConnCase, async: true

  defp assert_json_content_type(conn) do
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
  end

  defp assert_pretty(json_body) do
    assert String.contains?(json_body, "\n  ")
  end

  defp assert_not_pretty(json_body) do
    refute String.contains?(json_body, "\n")
  end

  defp decode_spec(conn) do
    Jason.decode!(conn.resp_body)
  end

  defp assert_is_spec(spec) do
    assert %{
             "openapi" => "3.1.1",
             "info" => %{"title" => _, "version" => _},
             "paths" => _
           } = spec
  end

  describe "PathsApiSpec integration" do
    test "serves JSON spec without pretty formatting by default", %{conn: conn} do
      conn = get(conn, ~p"/generated/openapi.json")

      assert_json_content_type(conn)
      assert_not_pretty(conn.resp_body)
      assert_is_spec(decode_spec(conn))
    end

    test "serves pretty-formatted JSON when pretty=true", %{conn: conn} do
      conn = get(conn, ~p"/generated/openapi.json?pretty=true")

      assert_json_content_type(conn)
      assert_pretty(conn.resp_body)

      assert %{"openapi" => "3.1.1"} = decode_spec(conn)
    end

    test "serves pretty-formatted JSON when pretty=1", %{conn: conn} do
      conn = get(conn, ~p"/generated/openapi.json?pretty=1")

      assert conn.status == 200
      assert_pretty(conn.resp_body)
    end

    test "serves compact JSON when pretty=false", %{conn: conn} do
      conn = get(conn, ~p"/generated/openapi.json?pretty=false")

      assert conn.status == 200
      assert_not_pretty(conn.resp_body)
    end

    test "serves compact JSON when pretty parameter is not provided", %{conn: conn} do
      conn = get(conn, ~p"/generated/openapi.json")

      assert conn.status == 200
      assert_not_pretty(conn.resp_body)
    end

    test "contains paths from PathsApiSpec filter", %{conn: conn} do
      # PathsApiSpec filters for "/generated" routes only
      conn = get(conn, ~p"/generated/openapi.json")

      path_keys = Map.keys(decode_spec(conn)["paths"])

      assert Enum.any?(path_keys, &String.starts_with?(&1, "/generated"))
      assert not Enum.any?(path_keys, &String.starts_with?(&1, "/provided"))
    end

    test "includes server configuration from PathsApiSpec", %{conn: conn} do
      conn = get(conn, ~p"/generated/openapi.json")

      assert %{"servers" => servers} = decode_spec(conn)
      assert is_list(servers)
      assert length(servers) > 0

      server_urls = Enum.map(servers, & &1["url"])
      assert Enum.any?(server_urls, &String.contains?(&1, "localhost"))
    end

    test "removes JSV internal metadata from spec", %{conn: conn} do
      conn = get(conn, ~p"/generated/openapi.json")

      assert not String.contains?(conn.resp_body, "jsv-cast")
    end

    test "sets CORS header for cross-origin access", %{conn: conn} do
      # The header is present because it is declared in the router
      conn = get(conn, ~p"/generated/openapi.json")

      assert conn.status == 200
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    end
  end

  describe "DeclarativeApiSpec integration" do
    test "serves DeclarativeApiSpec JSON", %{conn: conn} do
      conn = get(conn, ~p"/provided-openapi.json")

      assert_json_content_type(conn)
      assert_is_spec(decode_spec(conn))
    end

    test "serves pretty-formatted DeclarativeApiSpec when requested", %{conn: conn} do
      conn = get(conn, ~p"/provided-openapi.json?pretty=true")

      assert_json_content_type(conn)
      assert_pretty(conn.resp_body)

      assert_is_spec(decode_spec(conn))
    end
  end
end
