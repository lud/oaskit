defmodule Oaskit.TestWeb.Responder do
  alias Plug.Conn
  import ExUnit.Assertions

  @moduledoc false

  def embed_responder(conn, fun) do
    conn
    |> Conn.put_private(:responder_fun, fun)
    |> Conn.put_private(:responder_called, false)
  end

  def reply(conn, params) do
    case conn.private do
      %{responder_fun: fun} ->
        conn = Conn.put_private(conn, :responder_called, true)
        fun.(conn, params)

      _ ->
        ExUnit.Assertions.flunk("""
        Responder was not set
        """)
    end
  end

  def verify(conn) do
    case conn do
      %{state: :unset} ->
        flunk("response was not sent")

      %{private: %{responder_called: true}} ->
        conn

      %{
        private: %{
          responder_called: false,
          phoenix_controller: controller,
          phoenix_action: action
        },
        resp_body: resp_body
      } ->
        flunk("""
        #{inspect(controller)}.#{action} did not call the responder

        RESPONSE BODY
        #{resp_body}
        """)
    end
  end
end
