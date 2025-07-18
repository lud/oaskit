defmodule Oaskit.Spec.Callback do
  use Oaskit.Internal.SpecObject

  @deprecated "use #{inspect(__MODULE__)}.json_schema/0 instead"
  @doc false
  def schema do
    json_schema()
  end

  def json_schema do
    %{
      title: "Callback",
      type: :object,
      description:
        "Map of possible out-of-band callbacks related to the parent operation, mapping expressions to Path Item Objects.",
      additionalProperties: Oaskit.Spec.PathItem
    }
  end

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(default: {:or_ref, Oaskit.Spec.Response})
    |> normalize_subs(fn
      value, ctx -> {_, _} = normalize!(value, Oaskit.Spec.PathItem, ctx)
    end)
    |> collect()
  end
end
