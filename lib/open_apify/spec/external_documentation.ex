defmodule OpenApify.Spec.ExternalDocumentation do
  import JSV
  use OpenApify.Internal.SpecObject

  # Allows referencing an external resource for extended documentation.
  defschema %{
    title: "ExternalDocumentation",
    type: :object,
    description: "Allows referencing an external resource for extended documentation.",
    properties: %{
      description: %{type: :string, description: "A description of the target documentation."},
      url: %{type: :string, description: "A URI for the target documentation. Required."}
    },
    required: [:url]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default(:all)
    |> collect()
  end
end
