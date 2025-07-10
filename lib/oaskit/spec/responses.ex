defmodule Oaskit.Spec.Responses do
  use Oaskit.Internal.SpecObject

  @deprecated "use #{inspect(__MODULE__)}.json_schema/0 instead"
  @doc false
  def schema do
    json_schema()
  end

  def json_schema do
    %JSV.Schema{
      title: "Responses",
      type: :object,
      description: "Container for expected responses of an operation.",
      properties: %{
        default: %{
          anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Response],
          description:
            "Documentation of responses other than ones declared for specific HTTP response codes."
        }
      },
      minProperties: 1,
      additionalProperties: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Response]}
    }
  end

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(default: {:or_ref, Oaskit.Spec.Response})
    |> normalize_subs(
      {:or_ref,
       fn
         value, ctx -> {_, _} = normalize!(value, Oaskit.Spec.Response, ctx)
       end}
    )
    |> collect()
  end
end
