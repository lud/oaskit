defmodule Oaskit.TestWeb.Schemas.AlchemistsPage do
  alias Oaskit.TestWeb.Schemas.Alchemist

  require(JSV).defschema(%{
    type: :object,
    properties: %{
      data: %{type: :array, items: Alchemist}
    },
    required: [:data]
  })
end
