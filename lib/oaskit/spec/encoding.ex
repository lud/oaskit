defmodule Oaskit.Spec.Encoding do
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "Encoding",
    type: :object,
    description: "A single encoding definition applied to a single schema property.",
    properties: %{
      contentType: %{type: :string, description: "Content type"},
      headers: %{
        type: :object,
        additionalProperties: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Header]},
        description: "Headers"
      },
      style: %{type: :string, description: "Style"},
      explode: %{type: :boolean, description: "Explode"},
      allowReserved: %{type: :boolean, description: "Allow reserved"}
    },
    required: []
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(headers: {:map, {:or_ref, Oaskit.Spec.Header}})
    |> normalize_default(:all)
    |> collect()
  end
end
