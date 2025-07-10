defmodule Oaskit.Spec.SecurityRequirement do
  use Oaskit.Internal.SpecObject

  @deprecated "use #{inspect(__MODULE__)}.json_schema/0 instead"
  @doc false
  def schema do
    json_schema()
  end

  def json_schema do
    %{
      title: "SecurityRequirement",
      type: :object,
      description:
        "Lists required security schemes to execute an operation, mapping each scheme name to a list of scopes or roles.",
      additionalProperties: %{type: :array, items: %{type: :string}}
    }
  end

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default(:all)
    |> collect()
  end
end
