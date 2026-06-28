defmodule Oaskit.TestWeb.ResponseController do
  alias Oaskit.Spec.Reference
  alias Oaskit.TestWeb.Schemas.FortuneCookie
  alias Oaskit.TestWeb.Schemas.GenericError
  use Oaskit.TestWeb, :controller

  @moduledoc false

  @fortunes [
    %{category: "wisdom", message: "Patience is the greatest potion ingredient."},
    %{category: "humor", message: "Never trust a wizard with purple socks."},
    %{category: "warning", message: "Do not mix Phoenix Feather and Dragon Scale!"},
    %{category: "advice", message: "Don't trust Merlin's labels."}
  ]

  operation :no_operation, false

  def no_operation(conn, _) do
    text(conn, "not json")
  end

  operation :valid, operation_id: "fortune_valid", responses: [ok: FortuneCookie]

  def valid(conn, _) do
    json(conn, Enum.random(@fortunes))
  end

  operation :valid_no_operation, false

  def valid_no_operation(conn, _) do
    json(conn, Enum.random(@fortunes))
  end

  operation :valid_from_ref,
    operation_id: "fortune_from_ref",
    responses: [ok: %Reference{"$ref": "#/components/responses/SpecialFortune"}]

  def valid_from_ref(conn, _) do
    json(conn, Enum.random(@fortunes))
  end

  # Returns a response that does not match the schema (missing required field)
  operation :invalid, operation_id: "fortune_invalid", responses: [ok: FortuneCookie]

  def invalid(conn, _) do
    json(conn, %{message: 123})
  end

  # Returns a response with no content defined in the spec
  operation :no_content_def,
    operation_id: "fortune_no_content_def",
    responses: [ok: [description: "Hello"]]

  def no_content_def(conn, _) do
    text(conn, "anything")
  end

  # Returns a response with the wrong content-type (text/plain instead of application/json)
  operation :bad_content_type,
    operation_id: "fortune_bad_content_type",
    responses: [ok: {FortuneCookie, description: "hello!"}]

  def bad_content_type(conn, _) do
    text(conn, "not json")
  end

  operation :default_resp,
    operation_id: "fortune_default_resp",
    responses: %{
      200 => FortuneCookie,
      :default => [
        description: "some description",
        content: %{"application/json" => %{schema: GenericError}}
      ]
    }

  def default_resp(conn, _) do
    conn
    |> put_status(500)
    |> json(%{message: "too bad!", errcode: 123_456})
  end

  operation :invalid_default_resp,
    operation_id: "fortune_invalid_default_resp",
    responses: [ok: FortuneCookie, default: GenericError]

  def invalid_default_resp(conn, _) do
    conn
    |> put_status(500)
    |> json(%{message: "too bad!", errcode: "not an int"})
  end

  operation :require_body,
    operation_id: "fortune_requiring_params",
    request_body:
      {%{
         type: :object,
         properties: %{category: %{enum: ["wisdom", "humor", "warning", "advice"]}},
         required: [:category]
       }, description: "fortune selection"},
    responses: [
      ok: FortuneCookie,
      unprocessable_content: Oaskit.ErrorHandler.Default.ErrorResponseSchema,
      default: GenericError
    ]

  def require_body(conn, _) do
    category = Map.fetch!(body_params(conn), "category")
    json(conn, Enum.find(@fortunes, &(&1.category == category)))
  end

  # Response headers definition shared by the operations below. The header values
  # are always sent as strings; Oaskit casts them (simple style) before
  # validation, just like request header parameters. The "content-type" entry
  # must be ignored by the validator (OpenAPI mandates it), so its bogus integer
  # schema should never trigger an error.
  @fortune_headers %{
    "x-fortune-id" => %{schema: %{type: :string}, required: true},
    "x-fortune-count" => %{schema: %{type: :integer}},
    "x-fortune-tags" => %{schema: %{type: :array, items: %{type: :integer}}},
    "content-type" => %{schema: %{type: :integer}}
  }

  operation :valid_headers,
    operation_id: "fortune_valid_headers",
    responses: [ok: {FortuneCookie, headers: @fortune_headers}]

  def valid_headers(conn, _) do
    conn
    |> put_resp_header("x-fortune-id", "abc")
    |> put_resp_header("x-fortune-count", "5")
    |> put_resp_header("x-fortune-tags", "1,2,3")
    |> json(Enum.random(@fortunes))
  end

  operation :missing_required_header,
    operation_id: "fortune_missing_required_header",
    responses: [ok: {FortuneCookie, headers: @fortune_headers}]

  def missing_required_header(conn, _) do
    # The required "x-fortune-id" header is intentionally omitted.
    conn
    |> put_resp_header("x-fortune-count", "5")
    |> json(Enum.random(@fortunes))
  end

  operation :invalid_header,
    operation_id: "fortune_invalid_header",
    responses: [ok: {FortuneCookie, headers: @fortune_headers}]

  def invalid_header(conn, _) do
    conn
    |> put_resp_header("x-fortune-id", "abc")
    # Not an integer: the schema for "x-fortune-count" must reject it.
    |> put_resp_header("x-fortune-count", "not-an-int")
    |> json(Enum.random(@fortunes))
  end
end
