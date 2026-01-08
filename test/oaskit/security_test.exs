defmodule Oaskit.SecurityTest do
  use Oaskit.ConnCase, async: true

  @invalid_body %{"should_be" => "invalid"}
  @global_security [%{"global" => ["some:global1", "some:global2"]}]

  defp unauthorized_response(conn) do
    conn
    |> put_status(401)
    |> json(%{"error" => "unauthorized_from_test"})
    |> halt()
  end

  defp test_route(base_conn, route, expected_operation_id, expected_security) do
    # should return 401 when security fails

    conn401 =
      base_conn
      |> with_security(fn
        conn, opts ->
          assert expected_operation_id == opts[:operation_id]
          assert expected_security == opts[:security]
          assert :given_custom_opt == opts[:custom_opt]
          assert Keyword.has_key?(opts, :error_handler)
          unauthorized_response(conn)
      end)
      |> post(route, @invalid_body)
      |> check_security()

    assert %{"error" => "unauthorized_from_test"} == json_response(conn401, 401)

    # should return 422 when security is ok and validation fails

    conn422 =
      base_conn
      |> with_security(fn
        conn, opts ->
          assert expected_operation_id == opts[:operation_id]
          assert expected_security == opts[:security]
          assert :given_custom_opt == opts[:custom_opt]
          assert Keyword.has_key?(opts, :error_handler)
          conn
      end)
      |> post(route, @invalid_body)
      |> check_security()

    assert json_response(conn422, 422)
  end

  describe "security plug delegation with global security" do
    @base_url "/security"
    # Should use the globally defined security when security is not defined on
    # the operation
    test "/no-security", %{conn: conn} do
      test_route(conn, "#{@base_url}/no-security", "noSecurity", @global_security)
    end

    # empty list security is still given to the plug
    test "/empty-security", %{conn: conn} do
      test_route(conn, "#{@base_url}/empty-security", "emptySecurity", [])
    end

    test "/no-scopes", %{conn: conn} do
      test_route(conn, "#{@base_url}/no-scopes", "noScopes", [%{"someApiKey" => []}])
    end

    test "/with-scopes", %{conn: conn} do
      test_route(conn, "#{@base_url}/with-scopes", "withScopes", [
        %{"someApiKey" => ["some:scope1", "some:scope2"]}
      ])
    end

    test "/multi-scheme-security", %{conn: conn} do
      test_route(conn, "#{@base_url}/multi-scheme-security", "multiSchemeSecurity", [
        %{"someApiKey" => ["scope1", "scope2"], "someOauth" => ["so"]}
      ])
    end

    test "/multi-choice-security", %{conn: conn} do
      test_route(conn, "#{@base_url}/multi-choice-security", "multiChoiceSecurity", [
        %{"someApiKey" => ["scope1", "scope2"]},
        %{"someOauth" => ["so"]}
      ])
    end
  end

  describe "security without global" do
    @base_url "/security-no-global"

    # This test is different. No global security is defined, but the used
    # defined a security plug for validate request. In that case we will always
    # call the plug.
    #
    # And so we expect to be given `nil`
    test "/no-security", %{conn: conn} do
      test_route(conn, "#{@base_url}/no-security", "noSecurity", nil)
    end

    # empty list security is still given to the plug
    test "/empty-security", %{conn: conn} do
      test_route(conn, "#{@base_url}/empty-security", "emptySecurity", [])
    end

    test "/no-scopes", %{conn: conn} do
      test_route(conn, "#{@base_url}/no-scopes", "noScopes", [%{"someApiKey" => []}])
    end

    test "/with-scopes", %{conn: conn} do
      test_route(conn, "#{@base_url}/with-scopes", "withScopes", [
        %{"someApiKey" => ["some:scope1", "some:scope2"]}
      ])
    end

    test "/multi-scheme-security", %{conn: conn} do
      test_route(conn, "#{@base_url}/multi-scheme-security", "multiSchemeSecurity", [
        %{"someApiKey" => ["scope1", "scope2"], "someOauth" => ["so"]}
      ])
    end

    test "/multi-choice-security", %{conn: conn} do
      test_route(conn, "#{@base_url}/multi-choice-security", "multiChoiceSecurity", [
        %{"someApiKey" => ["scope1", "scope2"]},
        %{"someOauth" => ["so"]}
      ])
    end
  end
end
