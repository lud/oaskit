defmodule Oaskit.ConnCase do
  alias Oaskit.TestWeb.Responder
  alias Oaskit.TestWeb.SecurityPlug
  alias Phoenix.ConnTest
  alias Plug.Conn
  import ExUnit.Assertions
  require Phoenix.ConnTest
  use ExUnit.CaseTemplate

  @moduledoc false

  @endpoint Oaskit.TestWeb.Endpoint

  using do
    quote do
      @endpoint Oaskit.TestWeb.Endpoint

      import unquote(__MODULE__)
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.Controller, only: [json: 2, text: 2, html: 2]

      use Oaskit.TestWeb, :verified_routes
    end
  end

  setup tags do
    req_content_type = Map.get(tags, :req_content_type, "application/json")
    req_accept = Map.get(tags, :req_accept, "application/json")

    conn =
      ConnTest.build_conn()
      |> Conn.put_req_header("content-type", req_content_type)
      |> Conn.put_req_header("accept", req_accept)

    {:ok, conn: conn}
  end

  def with_response(conn, fun) when is_function(fun, 2) do
    Responder.embed_responder(conn, fun)
  end

  def check_responder(conn) do
    Responder.verify(conn)
  end

  def post_reply(conn, path, payload, fun) when is_function(fun, 2) do
    conn
    |> with_response(fun)
    |> ConnTest.post(path, payload)
    |> check_responder()
  end

  def get_reply(conn, path, query_params \\ [], fun) when is_function(fun, 2) do
    conn
    |> with_response(fun)
    |> ConnTest.get(path, query_params)
    |> check_responder()
  end

  def with_security(conn, fun) when is_function(fun) do
    SecurityPlug.embed_mock(conn, fun)
  end

  def with_security_noop(%{test: _, conn: %Plug.Conn{} = conn} = ctx) do
    Map.put(ctx, :conn, with_security_noop(conn))
  end

  def with_security_noop(%Plug.Conn{} = conn) do
    SecurityPlug.embed_mock(conn, fn conn, _ -> conn end)
  end

  def check_security(conn) do
    case conn do
      %{state: :unset} ->
        flunk("response was not sent")

      %{private: %{security_called: true}} ->
        conn

      %{
        private: %{
          security_called: false,
          phoenix_controller: controller,
          phoenix_action: action
        },
        resp_body: resp_body
      } ->
        flunk("""
        #{inspect(controller)}.#{action} did not call the security plug

        RESPONSE BODY
        #{resp_body}
        """)
    end
  end
end
