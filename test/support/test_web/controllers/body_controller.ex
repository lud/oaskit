defmodule Oaskit.TestWeb.BodyController do
  alias Oaskit.TestWeb.Responder
  alias Oaskit.TestWeb.Schemas.PlantSchema
  use JSV.Schema
  use Oaskit.TestWeb, :controller

  @moduledoc false

  @plant_schema %{
    type: :object,
    title: "InlinePlantSchema",
    properties: %{
      name: non_empty_string(),
      sunlight: string_enum_to_atom([:full_sun, :partial_sun, :bright_indirect, :darnkness])
    },
    required: [:name, :sunlight]
  }

  # pass the schema directly as the value of request_body
  operation :inline_single,
    request_body: {@plant_schema, []},
    responses: dummy_responses_with_error()

  def inline_single(conn, params) do
    Responder.reply(conn, params)
  end

  operation :module_single,
    operation_id: :custom_operation_id_module_single,
    request_body: PlantSchema,
    responses: dummy_responses_with_error()

  def module_single(conn, params) do
    Responder.reply(conn, params)
  end

  operation :module_single_not_required,
    request_body: {PlantSchema, [required: false]},
    responses: [
      ok: true,
      default: Oaskit.ErrorHandler.Default.error_response_schema()
    ]

  def module_single_not_required(conn, params) do
    Responder.reply(conn, params)
  end

  operation :handle_form,
    request_body: [content: %{"application/x-www-form-urlencoded" => %{schema: PlantSchema}}],
    responses: dummy_responses_with_error()

  def handle_form(conn, params) do
    Responder.reply(conn, params)
  end

  operation :manual_form_handle,
    request_body: [content: %{"application/x-www-form-urlencoded" => %{schema: PlantSchema}}],
    responses: dummy_responses_with_error()

  @spec manual_form_handle(term, term) :: no_return
  def manual_form_handle(_conn, _params) do
    raise "this should only be tested with invalid bodies"
  end

  operation :manual_form_show,
    responses: dummy_responses_with_error()

  def manual_form_show(conn, _params) do
    html(conn, """
    <form action="/generated/body/manual-form-handle" method="POST">
      <input type="text" name="dummy" />
      <input type="submit" value="OK" />
    </form>
    """)
  end

  def undefined_operation(conn, params) do
    Responder.reply(conn, params)
  end

  operation :ignored_action, false

  def ignored_action(conn, params) do
    Responder.reply(conn, params)
  end

  operation :wildcard_media_type,
    request_body: [
      required: false,
      content: %{
        "*/*" => %{schema: false},
        "application/json" => %{schema: PlantSchema}
      }
    ],
    responses: dummy_responses_with_error()

  def wildcard_media_type(conn, params) do
    Responder.reply(conn, params)
  end

  operation :boolean_schema_false,
    request_body: {false, required: false},
    responses: dummy_responses_with_error()

  def boolean_schema_false(conn, params) do
    Responder.reply(conn, params)
  end
end
