defmodule OpenApify.TestWeb.JsonErrorsController do
  alias OpenApify.TestWeb.Schemas.PlantSchema
  # -- equivalent of using the web :controller --------------------------------
  import Plug.Conn
  use OpenApify.Controller

  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: []

  plug OpenApify.Plugs.ValidateRequest, html_errors: false
  # ---------------------------------------------------------------------------

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
    responses: [ok: true]

  def create_plant(_conn, _params) do
    raise "only used with erroring payloads"
  end
end
