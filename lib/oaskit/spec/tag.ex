defmodule Oaskit.Spec.Tag do
  import JSV
  use Oaskit.Internal.SpecObject

  # Adds metadata to a single tag.
  defschema %{
    title: "Tag",
    type: :object,
    description: "Adds metadata to a single tag.",
    properties: %{
      name: %{type: :string, description: "The name of the tag. Required."},
      description: %{type: :string, description: "A description for the tag."},
      externalDocs: Oaskit.Spec.ExternalDocumentation
    },
    required: [:name]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([:name, :description])
    |> normalize_subs(externalDocs: Oaskit.Spec.ExternalDocumentation)
    |> collect()
  end
end
