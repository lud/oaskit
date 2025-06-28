defmodule Oaskit.Spec.Link do
  import JSV
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "Link",
    type: :object,
    description: "Represents a possible design-time link for a response.",
    properties: %{
      operationRef: %{type: :string, description: "Operation reference"},
      operationId: %{type: :string, description: "Operation ID"},
      parameters: %{
        type: :object,
        additionalProperties: %{description: "Parameter value"},
        description: "Parameters"
      },
      requestBody: %{description: "Request body"},
      description: %{type: :string, description: "Description"},
      server: Oaskit.Spec.Server
    },
    required: []
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(server: Oaskit.Spec.Server)
    |> normalize_default(:all)
    |> collect()
  end
end
