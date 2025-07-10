defmodule Oaskit.Spec.OAuthFlows do
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "OAuthFlows",
    type: :object,
    description: "Configures supported OAuth Flows for a security scheme.",
    properties: %{
      implicit: Oaskit.Spec.OAuthFlow,
      password: Oaskit.Spec.OAuthFlow,
      clientCredentials: Oaskit.Spec.OAuthFlow,
      authorizationCode: Oaskit.Spec.OAuthFlow
    },
    required: []
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      implicit: Oaskit.Spec.OAuthFlow,
      password: Oaskit.Spec.OAuthFlow,
      clientCredentials: Oaskit.Spec.OAuthFlow,
      authorizationCode: Oaskit.Spec.OAuthFlow
    )
    |> collect()
  end
end
