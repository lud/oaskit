defmodule Oaskit.TestWeb.OrvalController do
  use JSV.Schema
  use Oaskit.TestWeb, :controller

  @moduledoc false

  operation :test_arrays,
    operation_id: "TestArrays",
    parameters: [
      "simple_explode_integers[]": [in: :query, schema: array_of(integer())]
    ],
    responses: [
      ok: {object(), []},
      default: Oaskit.ErrorHandler.Default.error_response_schema()
    ]

  def test_arrays(conn, _params) do
    json(conn, conn.private.oaskit)
  end

  defschema UserBodySchema,
            ~SD"""
            Some body that needs to be respected by orval.

            Foo Bar Foo!
            """,
            name: string(),
            age: integer(),
            role: string_enum_to_atom([:admin, :user, :visitor], default: :admin)

  operation :create_user,
    operation_id: "CreateUser",
    request_body: UserBodySchema,
    responses: [ok: {object(), []}]

  def create_user(conn, _params) do
    json(conn, conn.private.oaskit)
  end
end
