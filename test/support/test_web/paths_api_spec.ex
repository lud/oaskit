defmodule OpenApify.TestWeb.PathsApiSpec do
  alias OpenApify.Spec.Paths
  alias OpenApify.Spec.Server
  use OpenApify

  @impl true
  def spec do
    %{
      openapi: "3.1.1",
      info: %{title: "OpenApify Test API", version: "0.0.0"},
      paths:
        Paths.from_router(OpenApify.TestWeb.Router,
          filter: fn route ->
            case route.path do
              "/generated" <> _ -> true
              _ -> false
            end
          end
        ),
      servers: [Server.from_config(:open_apify, OpenApify.TestWeb.Endpoint)]
    }
  end
end
