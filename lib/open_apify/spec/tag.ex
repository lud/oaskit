defmodule OpenApify.Spec.Tag do
  require JSV
  use OpenApify.Internal.SpecObject

  # Adds metadata to a single tag.
  JSV.defschema(%{
    title: "Tag",
    type: :object,
    description: "Adds metadata to a single tag.",
    properties: %{
      name: %{type: :string, description: "The name of the tag. Required."},
      description: %{type: :string, description: "A description for the tag."},
      externalDocs: OpenApify.Spec.ExternalDocumentation
    },
    required: [:name]
  })

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([:name, :description])
    |> normalize_subs(externalDocs: OpenApify.Spec.ExternalDocumentation)
    |> collect()
  end
end
