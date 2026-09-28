defmodule Oaskit.Spec.Response do
  alias Oaskit.Spec.MediaType
  alias Oaskit.Spec.Reference
  import Oaskit.Internal.ControllerBuilder
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "Response",
    type: :object,
    description: "Describes a single response from an API operation.",
    properties: %{
      description: %{type: :string, description: "A description of the response. Required."},
      headers: %{
        type: :object,
        additionalProperties: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Header]},
        description: "A map of header names to their definitions."
      },
      content: %{
        type: :object,
        additionalProperties: Oaskit.Spec.MediaType,
        description: "A map of potential response payloads by media type."
      },
      links: %{
        type: :object,
        additionalProperties: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Link]},
        description: "A map of operation links that can be followed from the response."
      }
    },
    required: [:description]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([:description])
    |> normalize_subs(
      headers: {:map, {:or_ref, Oaskit.Spec.Header}},
      content: {:map, Oaskit.Spec.MediaType},
      links: {:map, {:or_ref, Oaskit.Spec.Link}}
    )
    |> collect()
  end

  @doc false
  def from_controller!(%Reference{} = ref) do
    ref
  end

  def from_controller!(schema) when is_atom(schema) when is_boolean(schema) do
    from_controller!({schema, []})
  end

  def from_controller!({schema, spec})
      when is_map(schema)
      when is_atom(schema)
      when is_boolean(schema) do
    spec =
      Keyword.put_new_lazy(spec, :description, fn ->
        schema_description(schema) || "no description"
      end)

    case Keyword.fetch(spec, :content) do
      :error ->
        spec = Keyword.put(spec, :content, %{"application/json" => %{schema: schema}})
        from_controller!(spec)

      _ ->
        raise ArgumentError,
              "cannot use a tuple definition for response with the :content option"
    end
  end

  def from_controller!(spec) when is_list(spec) when is_map(spec) do
    spec
    |> make(__MODULE__)
    |> take_required(:description)
    |> take_default(:content, nil, &cast_content/1)
    |> take_default(:headers, nil)
    |> take_default(:links, nil)
    |> into()
  end

  defp cast_content(content) when is_map(content) when is_list(content) do
    MediaType.from_controller_content(content)
  end

  defp cast_content(content) do
    raise ArgumentError,
          "invalid :content given in response definition, expected map or keyword list, got: #{inspect(content)}"
  end
end
