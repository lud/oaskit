defmodule Oaskit.Spec.Discriminator do
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "Discriminator",
    type: :object,
    description:
      "Provides a hint about the expected schema when request bodies or responses may be one of several schemas, using a property name and optional mapping.",
    properties: %{
      propertyName: %{
        type: :string,
        description:
          "The name of the property in the payload with the discriminating value. Required."
      },
      mapping: %{
        type: :object,
        additionalProperties: %{type: :string},
        description: "Mappings between payload values and schema names or URI references."
      }
    },
    required: [:propertyName]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default(:all)
    |> collect()
  end
end
