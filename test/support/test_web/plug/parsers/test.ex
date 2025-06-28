defmodule Plug.Parsers.TEST do
  @moduledoc false
  def init(opts) do
    opts
  end

  def parse(conn, "test", "test", _headers, _opts) do
    # This allows to test an empty body. Because Plug.Parsers can only return
    # maps, Oaskit considers empty maps as an empty body, _i.e_ it is not
    # validated if RequestBody spec :required option is `false`.
    case Plug.Conn.read_body(conn) do
      {:ok, "", conn} -> {:ok, %{}, conn}
      {:ok, body, conn} -> {:ok, %{raw_body: body}, conn}
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end
end
