defmodule Oaskit.TestWeb.Responder do
  alias Plug.Conn

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
end
