defmodule Oaskit.TestWeb.PathsApiSpec do
  alias Oaskit.Spec.Paths
  alias Oaskit.Spec.Server
  use Oaskit

  @moduledoc false

  @impl true
  def spec do
    %{
      openapi: "3.1.1",
      info: %{title: "Oaskit Test API", version: "0.0.0"},
      paths:
        Paths.from_router(Oaskit.TestWeb.Router,
          filter: fn route ->
            case route.path do
              "/generated" <> _ -> true
              _ -> false
            end
          end
        ),
      servers: [Server.from_config(:oaskit, Oaskit.TestWeb.Endpoint)]
    }
  end
end
