defmodule Oaskit.Spec.OpenAPI do
  use Oaskit.Internal.SpecObject

  # Root object describing the entire OpenAPI document and its structure.
  defschema %{
    title: "OpenAPI",
    type: :object,
    description:
      "Root object of the OpenAPI description, containing metadata, paths, components, and more.",
    properties: %{
      openapi: %{
        type: :string,
        description:
          "The version number of the OpenAPI Specification used in this document. Required."
      },
      info: Oaskit.Spec.Info,
      jsonSchemaDialect: %{
        type: :string,
        default: "https://json-schema.org/draft/2020-12/schema",
        description: "The default value for the $schema keyword within Schema Objects."
      },
      servers: %{
        type: :array,
        items: Oaskit.Spec.Server,
        description: "An array of Server Objects providing connectivity information to the API."
      },
      paths: Oaskit.Spec.Paths,
      webhooks: %{
        type: :object,
        additionalProperties: Oaskit.Spec.PathItem,
        description: "A map of incoming webhooks that may be received as part of this API."
      },
      components: Oaskit.Spec.Components,
      security: %{
        type: :array,
        items: Oaskit.Spec.SecurityRequirement,
        description: "A list of security mechanisms that can be used across the API."
      },
      tags: %{
        type: :array,
        items: Oaskit.Spec.Tag,
        description: "A list of tags used by the OpenAPI description with additional metadata."
      },
      externalDocs: Oaskit.Spec.ExternalDocumentation
    },
    required: [:openapi, :info, :paths]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      components: Oaskit.Spec.Components,
      externalDocs: Oaskit.Spec.ExternalDocumentation,
      info: Oaskit.Spec.Info,
      openapi: :default,
      jsonSchemaDialect: :default,
      paths: Oaskit.Spec.Paths,
      security: {:list, Oaskit.Spec.SecurityRequirement},
      servers: {:list, Oaskit.Spec.Server},
      tags: {:list, Oaskit.Spec.Tag},
      webhooks: {:map, Oaskit.Spec.PathItem}
    )
    |> collect()
  end
end
