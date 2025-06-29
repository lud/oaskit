defmodule OpenApify.Spec.Components do
  import JSV
  use OpenApify.Internal.SpecObject

  # Holds reusable objects for different aspects of the OpenAPI Specification.
  defschema %{
    title: "Components",
    type: :object,
    description:
      "Holds reusable objects for different aspects of the OpenAPI Specification, such as schemas, responses, parameters, and more.",
    properties: %{
      schemas: %{
        type: :object,
        additionalProperties: OpenApify.Spec.SchemaWrapper,
        description: "A map of reusable Schema Objects."
      },
      responses: %{
        type: :object,
        additionalProperties: OpenApify.Spec.Response,
        description: "A map of reusable Response Objects or Reference Objects."
      },
      parameters: %{
        type: :object,
        additionalProperties: OpenApify.Spec.Parameter,
        description: "A map of reusable Parameter Objects or Reference Objects."
      },
      examples: %{
        type: :object,
        additionalProperties: OpenApify.Spec.Example,
        description: "A map of reusable Example Objects or Reference Objects."
      },
      requestBodies: %{
        type: :object,
        additionalProperties: OpenApify.Spec.RequestBody,
        description: "A map of reusable Request Body Objects or Reference Objects."
      },
      headers: %{
        type: :object,
        additionalProperties: OpenApify.Spec.Header,
        description: "A map of reusable Header Objects or Reference Objects."
      },
      securitySchemes: %{
        type: :object,
        additionalProperties: OpenApify.Spec.SecurityScheme,
        description: "A map of reusable Security Scheme Objects or Reference Objects."
      },
      links: %{
        type: :object,
        additionalProperties: OpenApify.Spec.Link,
        description: "A map of reusable Link Objects or Reference Objects."
      },
      callbacks: %{
        type: :object,
        additionalProperties: OpenApify.Spec.Callback,
        description: "A map of reusable Callback Objects or Reference Objects."
      },
      pathItems: %{
        type: :object,
        additionalProperties: OpenApify.Spec.PathItem,
        description: "A map of reusable Path Item Objects."
      }
    },
    required: []
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    # Schemas are handled at the top level when initializing the context
    |> skip(:schemas)
    |> normalize_subs(
      responses: {:map, OpenApify.Spec.Response},
      parameters: {:map, OpenApify.Spec.Parameter},
      examples: {:map, OpenApify.Spec.Example},
      requestBodies: {:map, OpenApify.Spec.RequestBody},
      headers: {:map, OpenApify.Spec.Header},
      securitySchemes: {:map, OpenApify.Spec.SecurityScheme},
      links: {:map, OpenApify.Spec.Link},
      callbacks: {:map, OpenApify.Spec.Callback},
      pathItems: {:map, OpenApify.Spec.PathItem}
    )
    |> collect()
  end
end
