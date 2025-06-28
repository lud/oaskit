defmodule Oaskit.Spec.Components do
  import JSV
  use Oaskit.Internal.SpecObject

  # Holds reusable objects for different aspects of the OpenAPI Specification.
  defschema %{
    title: "Components",
    type: :object,
    description:
      "Holds reusable objects for different aspects of the OpenAPI Specification, such as schemas, responses, parameters, and more.",
    properties: %{
      schemas: %{
        type: :object,
        additionalProperties: Oaskit.Spec.SchemaWrapper,
        description: "A map of reusable Schema Objects."
      },
      responses: %{
        type: :object,
        additionalProperties: Oaskit.Spec.Response,
        description: "A map of reusable Response Objects or Reference Objects."
      },
      parameters: %{
        type: :object,
        additionalProperties: Oaskit.Spec.Parameter,
        description: "A map of reusable Parameter Objects or Reference Objects."
      },
      examples: %{
        type: :object,
        additionalProperties: Oaskit.Spec.Example,
        description: "A map of reusable Example Objects or Reference Objects."
      },
      requestBodies: %{
        type: :object,
        additionalProperties: Oaskit.Spec.RequestBody,
        description: "A map of reusable Request Body Objects or Reference Objects."
      },
      headers: %{
        type: :object,
        additionalProperties: Oaskit.Spec.Header,
        description: "A map of reusable Header Objects or Reference Objects."
      },
      securitySchemes: %{
        type: :object,
        additionalProperties: Oaskit.Spec.SecurityScheme,
        description: "A map of reusable Security Scheme Objects or Reference Objects."
      },
      links: %{
        type: :object,
        additionalProperties: Oaskit.Spec.Link,
        description: "A map of reusable Link Objects or Reference Objects."
      },
      callbacks: %{
        type: :object,
        additionalProperties: Oaskit.Spec.Callback,
        description: "A map of reusable Callback Objects or Reference Objects."
      },
      pathItems: %{
        type: :object,
        additionalProperties: Oaskit.Spec.PathItem,
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
      responses: {:map, Oaskit.Spec.Response},
      parameters: {:map, Oaskit.Spec.Parameter},
      examples: {:map, Oaskit.Spec.Example},
      requestBodies: {:map, Oaskit.Spec.RequestBody},
      headers: {:map, Oaskit.Spec.Header},
      securitySchemes: {:map, Oaskit.Spec.SecurityScheme},
      links: {:map, Oaskit.Spec.Link},
      callbacks: {:map, Oaskit.Spec.Callback},
      pathItems: {:map, Oaskit.Spec.PathItem}
    )
    |> collect()
  end
end
