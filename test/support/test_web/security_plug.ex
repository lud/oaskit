defmodule Oaskit.TestWeb.SecurityPlug do
  @moduledoc """
  A mock security plug that calls a function stored in conn private data.
  Used for testing security validation in the pipeline.
  """

  def init(opts) do
    case opts[:security_fun] do
      fun when is_function(fun) -> fun.(:init, opts)
      nil -> opts
    end
  end

  def call(conn, opts) do
    case conn.private[:security_fun] do
      fun when is_function(fun) -> fun.(:call, {conn, opts})
      nil -> conn
    end
  end
end
