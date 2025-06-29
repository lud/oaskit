defmodule OpenApify.Spec.OpenAPI do
  import JSV
  use OpenApify.Internal.SpecObject

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
      info: OpenApify.Spec.Info,
      jsonSchemaDialect: %{
        type: :string,
        default: "https://json-schema.org/draft/2020-12/schema",
        description: "The default value for the $schema keyword within Schema Objects."
      },
      servers: %{
        type: :array,
        items: OpenApify.Spec.Server,
        description: "An array of Server Objects providing connectivity information to the API."
      },
      paths: OpenApify.Spec.Paths,
      webhooks: %{
        type: :object,
        additionalProperties: OpenApify.Spec.PathItem,
        description: "A map of incoming webhooks that may be received as part of this API."
      },
      components: OpenApify.Spec.Components,
      security: %{
        type: :array,
        items: OpenApify.Spec.SecurityRequirement,
        description: "A list of security mechanisms that can be used across the API."
      },
      tags: %{
        type: :array,
        items: OpenApify.Spec.Tag,
        description: "A list of tags used by the OpenAPI description with additional metadata."
      },
      externalDocs: OpenApify.Spec.ExternalDocumentation
    },
    required: [:openapi, :info, :paths]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      components: OpenApify.Spec.Components,
      externalDocs: OpenApify.Spec.ExternalDocumentation,
      info: OpenApify.Spec.Info,
      openapi: :default,
      jsonSchemaDialect: :default,
      paths: OpenApify.Spec.Paths,
      security: {:list, OpenApify.Spec.SecurityRequirement},
      servers: {:list, OpenApify.Spec.Server},
      tags: {:list, OpenApify.Spec.Tag},
      webhooks: {:map, OpenApify.Spec.PathItem}
    )
    |> collect()
  end
end
