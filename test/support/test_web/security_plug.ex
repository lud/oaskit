defmodule Oaskit.TestWeb.SecurityPlug do
  alias Plug.Conn
  import ExUnit.Assertions

  @moduledoc """
  A mock security plug that calls a function stored in conn private data. Used
  for testing security validation in the pipeline.

  The fun is set in the conn as a private data, and so can only be called from
  the call/2 callback. The init/1 callback will simply return the opts as they
  are.
  """

  def init(opts) do
    assert Keyword.has_key?(opts, :operation_id)
    assert Keyword.has_key?(opts, :security)

    # This assertion is only valid as we do not pass a tuple when defining the
    # security plug.
    assert Keyword.has_key?(opts, :error_handler)

    opts
  end

  def call(conn, opts) do
    case conn.private[:security_fun] do
      fun when is_function(fun) ->
        conn = Conn.put_private(conn, :security_called, true)
        fun.(conn, opts)

      nil ->
        raise("security plug is not defined")
        conn
    end
  end

  def embed_mock(conn, fun) when is_function(fun, 2) do
    conn
    |> Conn.put_private(:security_fun, fun)
    |> Conn.put_private(:security_called, false)
  end

  def verify(conn) do
    case conn do
      %{state: :unset} ->
        flunk("response was not sent")

      %{private: %{security_called: true}} ->
        conn

      %{
        private: %{
          oaskit: %{operation_id: operation_id},
          security_called: false
        },
        resp_body: resp_body
      } ->
        flunk("""
        security was not called for operation #{operation_id}

        RESPONSE BODY
        #{resp_body}
        """)
    end
  end
end
