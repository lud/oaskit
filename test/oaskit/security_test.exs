defmodule Oaskit.SecurityTest do
  use Oaskit.ConnCase, async: true

  @invalid_body %{"should_be" => "invalid"}

  defp assert_security(opts, expected_operation_id, expected_security) do
    assert expected_operation_id == opts[:operation_id]
    assert expected_security == opts[:security]
    opts
  end

  defp unauthorized_response(conn) do
    conn
    |> put_status(401)
    |> json(%{"error" => "unauthorized_from_test"})
    |> halt()
  end

  describe "POST /no-security" do
    test "valid request returns 200", %{conn: conn} do
      conn = post(conn, "/generated/security/no-security", @invalid_body)
      assert json_response(conn, 422)
    end

    test "invalid request returns 422", %{conn: conn} do
      conn = post(conn, "/generated/security/no-security", @invalid_body)
      assert json_response(conn, 422)
    end
  end

  describe "POST /empty-security" do
    test "valid request returns 200", %{conn: conn} do
      conn = post(conn, "/generated/security/empty-security", @invalid_body)
      assert json_response(conn, 422)
    end

    test "invalid request returns 422", %{conn: conn} do
      conn = post(conn, "/generated/security/empty-security", @invalid_body)
      assert json_response(conn, 422)
    end
  end

  describe "POST /no-scopes" do
    test "returns 200 when security plug allows", %{conn: conn} do
      conn =
        conn
        |> with_security(fn
          :init, opts -> assert_security(opts, "noScopes", [%{"someApiKey" => []}])
          :call, {conn, _opts} -> conn
        end)
        |> post("/generated/security/no-scopes", @invalid_body)

      assert json_response(conn, 422)
    end

    test "returns 401 when security plug halts", %{conn: conn} do
      conn =
        conn
        |> with_security(fn
          :init, opts -> assert_security(opts, "noScopes", [%{"someApiKey" => []}])
          :call, {conn, _opts} -> unauthorized_response(conn)
        end)
        |> post("/generated/security/no-scopes", @invalid_body)

      assert %{"error" => "unauthorized_from_test"} == json_response(conn, 401)
    end
  end

  describe "POST /with-scopes" do
    test "returns 200 when security plug allows", %{conn: conn} do
      conn =
        conn
        |> with_security(fn
          :init, opts ->
            assert_security(opts, "withScopes", [
              %{"someApiKey" => ["some:scope1", "some:scope2"]}
            ])

          :call, {conn, _opts} ->
            conn
        end)
        |> post("/generated/security/with-scopes", @invalid_body)

      assert json_response(conn, 422)
    end

    test "returns 401 when security plug halts", %{conn: conn} do
      conn =
        conn
        |> with_security(fn
          :init, opts ->
            assert_security(opts, "withScopes", [
              %{"someApiKey" => ["some:scope1", "some:scope2"]}
            ])

          :call, {conn, _opts} ->
            unauthorized_response(conn)
        end)
        |> post("/generated/security/with-scopes", @invalid_body)

      assert %{"error" => "unauthorized_from_test"} == json_response(conn, 401)
    end
  end

  describe "POST /multi-scheme-security" do
    test "returns 200 when security plug allows", %{conn: conn} do
      conn =
        conn
        |> with_security(fn
          :init, opts ->
            assert_security(opts, "multiSchemeSecurity", [
              %{"someApiKey" => ["scope1", "scope2"], "someOauth" => ["so"]}
            ])

          :call, {conn, _opts} ->
            conn
        end)
        |> post("/generated/security/multi-scheme-security", @invalid_body)

      assert json_response(conn, 422)
    end

    test "returns 401 when security plug halts", %{conn: conn} do
      conn =
        conn
        |> with_security(fn
          :init, opts ->
            assert_security(opts, "multiSchemeSecurity", [
              %{"someApiKey" => ["scope1", "scope2"], "someOauth" => ["so"]}
            ])

          :call, {conn, _opts} ->
            unauthorized_response(conn)
        end)
        |> post("/generated/security/multi-scheme-security", @invalid_body)

      assert %{"error" => "unauthorized_from_test"} == json_response(conn, 401)
    end
  end

  describe "POST /multi-choice-security" do
    test "returns 200 when security plug allows", %{conn: conn} do
      conn =
        conn
        |> with_security(fn
          :init, opts ->
            assert_security(opts, "multiChoiceSecurity", [
              %{"someApiKey" => ["scope1", "scope2"]},
              %{"someOauth" => ["so"]}
            ])

          :call, {conn, _opts} ->
            conn
        end)
        |> post("/generated/security/multi-choice-security", @invalid_body)

      assert json_response(conn, 422)
    end

    test "returns 401 when security plug halts", %{conn: conn} do
      conn =
        conn
        |> with_security(fn
          :init, opts ->
            assert_security(opts, "multiChoiceSecurity", [
              %{"someApiKey" => ["scope1", "scope2"]},
              %{"someOauth" => ["so"]}
            ])

          :call, {conn, _opts} ->
            unauthorized_response(conn)
        end)
        |> post("/generated/security/multi-choice-security", @invalid_body)

      assert %{"error" => "unauthorized_from_test"} == json_response(conn, 401)
    end
  end
end
