defmodule Oaskit.TestWeb.Schemas.AlchemistsPage do
  @moduledoc false

  alias Oaskit.TestWeb.Schemas.Alchemist
  use JSV.Schema

  defschema %{
    type: :object,
    properties: %{
      data: %{type: :array, items: Alchemist}
    },
    required: [:data]
  }
end
