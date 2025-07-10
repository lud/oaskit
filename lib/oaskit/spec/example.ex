defmodule Oaskit.Spec.Example do
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "Example",
    type: :object,
    description: "Groups an example value with metadata.",
    properties: %{
      summary: %{type: :string, description: "A short description for the example."},
      description: %{type: :string, description: "A long description for the example."},
      value: %{description: "An embedded literal example. Mutually exclusive with externalValue."},
      externalValue: %{
        type: :string,
        description: "A URI that identifies the literal example. Mutually exclusive with value."
      }
    },
    required: []
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default(:all)
    |> collect()
  end
end
