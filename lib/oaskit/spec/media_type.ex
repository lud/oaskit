defmodule Oaskit.Spec.MediaType do
  alias Oaskit.Spec.Reference
  import Oaskit.Internal.ControllerBuilder
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "MediaType",
    type: :object,
    description: "Provides schema and examples for a media type.",
    properties: %{
      schema: Oaskit.Spec.SchemaWrapper,
      examples: %{
        type: :object,
        additionalProperties: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Example]},
        description: "Examples"
      },
      encoding: %{
        type: :object,
        additionalProperties: Oaskit.Spec.Encoding,
        description: "Encoding"
      }
    },
    required: []
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      examples: {:map, {:or_ref, :default}},
      encoding: {:map, Oaskit.Spec.Encoding}
    )
    |> normalize_schema(:schema)
    |> collect()
  end

  @doc false
  def from_controller!(%Reference{} = ref) do
    ref
  end

  def from_controller!(spec) do
    spec
    |> make(__MODULE__)
    |> take_required(:schema, &ensure_schema/1)
    |> take_examples(spec)
    |> into()
  end

  @doc false
  def from_controller_content(content) do
    Enum.reduce_while(content, {:ok, %{}}, fn
      {mime_type, _media_spec}, _ when not is_binary(mime_type) ->
        {:halt, {:error, "media mime types must be strings, got: #{inspect(mime_type)}"}}

      {mime_type, media_spec}, {:ok, acc} ->
        case Plug.Conn.Utils.media_type(mime_type) do
          {:ok, _, _, _} ->
            {:cont, {:ok, Map.put(acc, mime_type, from_controller!(media_spec))}}

          :error ->
            {:halt, {:error, "cannot parse media type #{inspect(mime_type)}"}}
        end
    end)
  end
end
