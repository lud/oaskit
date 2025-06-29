defmodule Oaskit.TestWeb do
  @moduledoc false

  def controller do
    quote do
      use Oaskit.Controller
      import Plug.Conn

      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: []

      import Oaskit.TestWeb.Helpers

      plug Oaskit.Plugs.ValidateRequest

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Oaskit.TestWeb.Endpoint,
        router: Oaskit.TestWeb.Router
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
