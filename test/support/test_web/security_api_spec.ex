defmodule Oaskit.TestWeb.SecurityApiSpec do
  alias Oaskit.Spec.Paths
  alias Oaskit.Spec.Server
  use Oaskit

  @moduledoc false

  @impl true
  def spec do
    %{
      openapi: "3.1.1",
      info: %{title: "Oaskit Security API", version: "0.0.0"},
      paths:
        Paths.from_router(Oaskit.TestWeb.Router,
          filter: fn route ->
            case route.path do
              "/security" <> _ -> true
              _ -> false
            end
          end
        ),
      servers: [Server.from_config(:oaskit, Oaskit.TestWeb.Endpoint)],
      # This is the default global security scheme that applies to all
      # operations from this spec.
      security: [%{"global" => ["some:global1", "some:global2"]}],
      components: %{
        securitySchemes: %{
          globalSec: %{
            description: "an API key",
            type: "apiKey",
            name: "api-key",
            in: "header"
          },
          someApiKey: %{
            description: "an API key",
            type: "apiKey",
            name: "api-key",
            in: "header"
          },
          someOauth: %{
            type: "oauth2",
            flows: %{
              authorizationCode: %{
                authorizationUrl: "https://learn.openapis.org/oauth/2.0/auth",
                tokenUrl: "https://learn.openapis.org/oauth/2.0/token",
                scopes: %{
                  "some:scope1": "Some Description",
                  "some:scope2": "Some Description"
                }
              }
            }
          }
        }
      }
    }
  end
end
