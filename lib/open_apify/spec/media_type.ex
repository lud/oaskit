defmodule OpenApify.Spec.MediaType do
  alias OpenApify.Spec.Reference
  import OpenApify.Internal.ControllerBuilder
  require JSV
  use OpenApify.Internal.SpecObject

  JSV.defschema(%{
    title: "MediaType",
    type: :object,
    description: "Provides schema and examples for a media type.",
    properties: %{
      schema: OpenApify.Spec.SchemaWrapper,
      examples: %{
        type: :object,
        additionalProperties: %{anyOf: [OpenApify.Spec.Reference, OpenApify.Spec.Example]},
        description: "Examples"
      },
      encoding: %{
        type: :object,
        additionalProperties: OpenApify.Spec.Encoding,
        description: "Encoding"
      }
    },
    required: []
  })

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([:tags, :summary, :description, :operationId, :deprecated, :encoding])
    |> normalize_subs(
      examples: {:map, {:or_ref, :default}},
      encoding: {:map, OpenApify.Spec.Encoding}
    )
    |> normalize_schema(:schema)
    |> collect()
  end

  def from_controller!(%Reference{} = ref) do
    ref
  end

  def from_controller!(spec) do
    spec
    |> build(__MODULE__)
    |> take_required(:schema)
    |> take_default_lazy(:examples, fn ->
      case Access.fetch(spec, :example) do
        {:ok, example} -> %{"default" => example}
        :error -> nil
      end
    end)
    |> into()
  end
end
