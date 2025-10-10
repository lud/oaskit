defmodule Oaskit.TestWeb.SecurityController do
  use Oaskit.TestWeb, :controller

  @common_request_schema %{
    "type" => "object",
    "required" => ["should_be"],
    "properties" => %{
      "should_be" => %{"const" => "valid"}
    }
  }

  @common_response_schema true

  operation :no_security,
    operation_id: "noSecurity",
    request_body: {@common_request_schema, description: "common body"},
    responses: [ok: {@common_response_schema, description: "common response"}]

  def no_security(conn, _params) do
    json(conn, %{})
  end

  operation :empty_security,
    operation_id: "emptySecurity",
    security: [],
    request_body: {@common_request_schema, description: "common body"},
    responses: [ok: {@common_response_schema, description: "common response"}]

  def empty_security(conn, _params) do
    json(conn, %{})
  end

  operation :false_security,
    operation_id: "falseSecurity",
    security: false,
    request_body: {@common_request_schema, description: "common body"},
    responses: [ok: {@common_response_schema, description: "common response"}]

  def false_security(conn, _params) do
    json(conn, %{})
  end

  operation :no_scopes,
    operation_id: "noScopes",
    security: [%{someApiKey: []}],
    request_body: {@common_request_schema, description: "common body"},
    responses: [ok: {@common_response_schema, description: "common response"}]

  def no_scopes(conn, _params) do
    json(conn, %{})
  end

  operation :with_scopes,
    operation_id: "withScopes",
    security: [%{"someApiKey" => ["some:scope1", "some:scope2"]}],
    request_body: {@common_request_schema, description: "common body"},
    responses: [ok: {@common_response_schema, description: "common response"}]

  def with_scopes(conn, _params) do
    json(conn, %{})
  end

  operation :multi_scheme_security,
    operation_id: "multiSchemeSecurity",
    security: [%{"someApiKey" => ["scope1", "scope2"], "someOauth" => ["so"]}],
    request_body: {@common_request_schema, description: "common body"},
    responses: [ok: {@common_response_schema, description: "common response"}]

  def multi_scheme_security(conn, _params) do
    json(conn, %{})
  end

  operation :multi_choice_security,
    operation_id: "multiChoiceSecurity",
    security: [%{"someApiKey" => ["scope1", "scope2"]}, %{"someOauth" => ["so"]}],
    request_body: {@common_request_schema, description: "common body"},
    responses: [ok: {@common_response_schema, description: "common response"}]

  def multi_choice_security(conn, _params) do
    json(conn, %{})
  end
end
