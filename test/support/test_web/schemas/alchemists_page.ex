defmodule OpenApify.TestWeb.Schemas.AlchemistsPage do
  alias OpenApify.TestWeb.Schemas.Alchemist

  require(JSV).defschema(%{
    type: :object,
    properties: %{
      data: %{type: :array, items: Alchemist}
    },
    required: [:data]
  })
end
