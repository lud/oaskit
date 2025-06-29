defmodule OpenApify.Spec.Responses do
  use OpenApify.Internal.SpecObject

  # Container for expected responses of an operation.
  def schema do
    %JSV.Schema{
      title: "Responses",
      type: :object,
      description: "Container for expected responses of an operation.",
      properties: %{
        default: %{
          anyOf: [OpenApify.Spec.Reference, OpenApify.Spec.Response],
          description:
            "Documentation of responses other than ones declared for specific HTTP response codes."
        }
      },
      minProperties: 1,
      additionalProperties: %{anyOf: [OpenApify.Spec.Reference, OpenApify.Spec.Response]}
    }
  end

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(default: {:or_ref, OpenApify.Spec.Response})
    |> normalize_subs(
      {:or_ref,
       fn
         value, ctx -> {_, _} = normalize!(value, OpenApify.Spec.Response, ctx)
       end}
    )
    |> collect()
  end
end
