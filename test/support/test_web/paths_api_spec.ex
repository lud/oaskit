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
      servers: [Server.from_config(:oaskit, Oaskit.TestWeb.Endpoint)],
      components: %{
        responses: %{
          SpecialFortune: %{
            description: "A response to be used from a $ref",
            content: %{
              "application/json": %{
                schema: %{
                  type: :object,
                  properties: %{
                    category: %{enum: ~w(wisdom humor warning advice)},
                    message: %{type: :string}
                  },
                  required: [:category, :message]
                }
              }
            }
          }
        },
        securitySchemes: %{
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
