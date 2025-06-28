defmodule OpenApify.Spec.OAuthFlow do
  require JSV
  use OpenApify.Internal.SpecObject

  # Configuration details for a supported OAuth Flow.
  JSV.defschema(%{
    title: "OAuthFlow",
    type: :object,
    description: "Configuration details for a supported OAuth Flow.",
    properties: %{
      authorizationUrl: %{
        type: :string,
        description:
          "The authorization URL for this flow. Required for implicit and authorizationCode flows."
      },
      tokenUrl: %{
        type: :string,
        description:
          "The token URL for this flow. Required for password, clientCredentials, and authorizationCode flows."
      },
      refreshUrl: %{type: :string, description: "The URL for obtaining refresh tokens."},
      scopes: %{
        type: :object,
        additionalProperties: %{type: :string},
        description: "A map of available scopes for the OAuth2 security scheme. Required."
      }
    },
    required: [:scopes]
  })

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([:authorizationUrl, :tokenUrl, :refreshUrl, :scopes])
    |> collect()
  end
end
