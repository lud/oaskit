defmodule Oaskit.Application do
  use Application

  @moduledoc false

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Oaskit.SpecBuilderLockRegistry}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Oaskit.Supervisor)
  end
end
