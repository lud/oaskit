defmodule Oaskit.Spec.SecurityScheme do
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "SecurityScheme",
    type: :object,
    description: "Defines a security scheme for operations.",
    properties: %{
      type:
        string_enum_to_atom(
          [
            :apiKey,
            :http,
            :mutualTLS,
            :oauth2,
            :openIdConnect
          ],
          description:
            "The type of the security scheme. Allowed values: apiKey, http, mutualTLS, oauth2, openIdConnect. Required."
        ),
      description: %{type: :string, description: "A description for the security scheme."},
      name: %{
        type: :string,
        description:
          "The name of the header, query, or cookie parameter (for apiKey). Required for apiKey."
      },
      in:
        string_enum_to_atom(
          [
            :query,
            :header,
            :cookie
          ],
          description:
            "The location of the API key. Allowed values: query, header, cookie. Required for apiKey."
        ),
      scheme: %{
        type: :string,
        description: "The HTTP authentication scheme name. Required for http."
      },
      bearerFormat: %{
        type: :string,
        description: "The format of the bearer token (for http with 'bearer' scheme)."
      },
      flows: Oaskit.Spec.OAuthFlows,
      openIdConnectUrl: %{
        type: :string,
        description:
          "The URL to discover OpenID Connect configuration. Required for openIdConnect."
      }
    },
    required: [:type]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([
      :type,
      :description,
      :name,
      :in,
      :scheme,
      :bearerFormat,
      :openIdConnectUrl
    ])
    |> normalize_subs(flows: Oaskit.Spec.OAuthFlows)
    |> collect()
  end
end
