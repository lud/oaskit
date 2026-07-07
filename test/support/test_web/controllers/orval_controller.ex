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

  defmodule UserBodySchema do
    @moduledoc false
    use JSV.Schema

    if Code.ensure_loaded?(JSON.Encoder) do
      @derive JSON.Encoder
    end

    if Code.ensure_loaded?(Jason.Encoder) do
      @derive Jason.Encoder
    end

    defschema %{
      type: :object,
      title: "UserBodySchema",
      description: ~SD"""
      Some body that needs to be respected by orval.

      Foo Bar Foo!
      """,
      properties: %{
        name: string(),
        age: integer(),
        role: string_enum_to_atom([:admin, :user, :visitor], default: :admin)
      },
      required: [:name, :age]
    }
  end

  operation :create_user,
    operation_id: "CreateUser",
    request_body: UserBodySchema,
    responses: [ok: {object(), []}]

  def create_user(conn, _params) do
    json(conn, conn.private.oaskit)
  end
end
