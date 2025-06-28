defmodule OpenApify.TestWeb do
  def controller do
    quote do
      use OpenApify.Controller
      import Plug.Conn

      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: []

      import OpenApify.TestWeb.Helpers

      plug OpenApify.Plugs.ValidateRequest

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: OpenApify.TestWeb.Endpoint,
        router: OpenApify.TestWeb.Router
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

defmodule OpenApify.TestWeb.Helpers do
  def dummy_responses do
    [ok: {%{_dummy_schema: true}, []}]
  end
end
