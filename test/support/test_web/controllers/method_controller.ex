defmodule Oaskit.TestWeb.MethodController do
  alias Oaskit.TestWeb.Responder
  alias Oaskit.TestWeb.Schemas.RespSchema
  use Oaskit.TestWeb, :controller

  @moduledoc false

  response = RespSchema

  operation :same_fun, operation_id: "mGET", responses: [ok: response], method: :get
  operation :same_fun, operation_id: "mPOST", responses: [ok: response], method: :post
  operation :same_fun, operation_id: "mPUT", responses: [ok: response], method: :put
  operation :same_fun, operation_id: "mDELETE", responses: [ok: response], method: :delete
  operation :same_fun, operation_id: "mOPTIONS", responses: [ok: response], method: :options
  operation :same_fun, operation_id: "mHEAD", responses: [ok: response], method: :head
  operation :same_fun, operation_id: "mPATCH", responses: [ok: response], method: :patch
  operation :same_fun, operation_id: "mTRACE", responses: [ok: response], method: :trace

  def same_fun(conn, params) do
    Responder.reply(conn, params)
  end
end
