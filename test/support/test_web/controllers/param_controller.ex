defmodule Oaskit.TestWeb.ParamController do
  alias Oaskit.TestWeb.Responder
  use JSV.Schema
  use Oaskit.TestWeb, :controller

  @moduledoc false

  @shape string_enum_to_atom([:square, :circle])
  @theme string_enum_to_atom([:dark, :light])
  @color string_enum_to_atom([:red, :blue])
  @query_int integer(minimum: 10, maximum: 100)

  # TODO(doc) import formatter in readme

  operation :no_params, responses: [ok: true]

  def no_params(conn, params) do
    Responder.reply(conn, params)
  end

  # Parameter is defined after some operations. Operations above does not have
  # this parameter.
  parameter :slug, in: :path, schema: %{type: :string, pattern: "[a-z-]+"}

  operation :generic_param_types,
    parameters: [
      string_param: [in: :query, schema: string()],
      boolean_param: [in: :query, schema: boolean()],
      integer_param: [in: :query, schema: integer()],
      number_param: [in: :query, schema: number()]
    ],
    responses: dummy_responses_with_error()

  def generic_param_types(conn, params) do
    Responder.reply(conn, params)
  end

  operation :single_path_param,
    parameters: [
      theme: [in: :path, schema: @theme]
    ],
    responses: dummy_responses_with_error()

  def single_path_param(conn, params) do
    Responder.reply(conn, params)
  end

  operation :two_path_params,
    parameters: [
      theme: [in: :path, schema: @theme],
      color: [in: :path, schema: @color]
    ],
    responses: dummy_responses_with_error()

  def two_path_params(conn, params) do
    Responder.reply(conn, params)
  end

  operation :scope_only,
    parameters: [
      shape: [in: :path, schema: @shape]
    ],
    responses: dummy_responses_with_error()

  def scope_only(conn, params) do
    Responder.reply(conn, params)
  end

  operation :scope_and_single,
    parameters: [
      shape: [in: :path, schema: @shape],
      theme: [in: :path, schema: @theme]
    ],
    responses: dummy_responses_with_error()

  def scope_and_single(conn, params) do
    Responder.reply(conn, params)
  end

  operation :scope_and_two_path_params,
    parameters: [
      shape: [in: :path, schema: @shape],
      theme: [in: :path, schema: @theme],
      color: [in: :path, schema: @color],
      shape: [in: :query, schema: @query_int, required: true],
      theme: [in: :query, schema: @query_int],
      # That last param uses a self ref and it should work. But it causes a
      # problem with the openapi-spec-validator python tool because it seem to
      # only validate according to Draft 7.
      color: [
        in: :query,
        schema: %{
          "$id" => "test://test",
          "d" => %{"shape" => @query_int},
          "$ref" => "test://test#/d/shape"
        }
      ]
    ],
    responses: dummy_responses_with_error()

  def scope_and_two_path_params(conn, params) do
    Responder.reply(conn, params)
  end

  operation :boolean_schema_false,
    parameters: [
      reject_me: [in: :query, schema: false],
      also_reject: [in: :query, schema: false]
    ],
    responses: dummy_responses_with_error()

  def boolean_schema_false(conn, params) do
    Responder.reply(conn, params)
  end

  operation :array_types,
    parameters: [
      numbers: [in: :query, schema: array_of(integer())],
      names: [in: :query, schema: array_of(string())]
    ],
    responses: dummy_responses_with_error()

  def array_types(conn, params) do
    Responder.reply(conn, params)
  end

  operation :explicit_brackets,
    parameters: [
      "users[]": [in: :query, schema: array_of(string())],
      "ids[]": [in: :query, schema: array_of(integer())]
    ],
    responses: dummy_responses_with_error()

  def explicit_brackets(conn, params) do
    Responder.reply(conn, params)
  end
end
