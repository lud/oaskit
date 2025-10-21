defmodule Oaskit.TestWeb.JsonErrorsController do
  alias Oaskit.ErrorHandler.Default.ErrorResponseSchema
  alias Oaskit.TestWeb.Schemas.PlantSchema
  # -- equivalent of using the web :controller --------------------------------
  import Plug.Conn
  use Oaskit.Controller

  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: []

  plug Oaskit.Plugs.ValidateRequest, html_errors: false
  # ---------------------------------------------------------------------------

  @moduledoc false

  operation :create_plant,
    parameters: [
      an_int: [in: :query, required: true, schema: %{type: :integer}]
    ],
    request_body: [
      required: true,
      content: %{
        "application/json" => [schema: PlantSchema],
        "application/x-www-form-urlencoded" => [schema: PlantSchema]
      }
    ],
    responses: [ok: true, default: ErrorResponseSchema]

  @spec create_plant(term, term) :: no_return()
  def create_plant(_conn, _params) do
    raise "this route is only used with invalid payloads"
  end
end
