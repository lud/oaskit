defmodule OpenApify.Spec.OAuthFlows do
  require JSV
  use OpenApify.Internal.SpecObject

  # Configures supported OAuth Flows for a security scheme.
  JSV.defschema(%{
    title: "OAuthFlows",
    type: :object,
    description: "Configures supported OAuth Flows for a security scheme.",
    properties: %{
      implicit: OpenApify.Spec.OAuthFlow,
      password: OpenApify.Spec.OAuthFlow,
      clientCredentials: OpenApify.Spec.OAuthFlow,
      authorizationCode: OpenApify.Spec.OAuthFlow
    },
    required: []
  })

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      implicit: OpenApify.Spec.OAuthFlow,
      password: OpenApify.Spec.OAuthFlow,
      clientCredentials: OpenApify.Spec.OAuthFlow,
      authorizationCode: OpenApify.Spec.OAuthFlow
    )
    |> collect()
  end
end
