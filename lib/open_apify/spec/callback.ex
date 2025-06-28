defmodule OpenApify.Spec.Callback do
  require JSV
  use OpenApify.Internal.SpecObject

  # Map of possible out-of-band callbacks related to the parent operation.
  def schema do
    %{
      title: "Callback",
      type: :object,
      description:
        "Map of possible out-of-band callbacks related to the parent operation, mapping expressions to Path Item Objects.",
      additionalProperties: OpenApify.Spec.PathItem
    }
  end

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(default: {:or_ref, OpenApify.Spec.Response})
    |> normalize_subs(fn
      value, ctx -> {_, _} = normalize!(value, OpenApify.Spec.PathItem, ctx)
    end)
    |> collect()
  end
end
