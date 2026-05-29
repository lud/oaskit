defmodule Oaskit.TestWeb.Schemas.Alchemist do
  @moduledoc false

  use JSV.Schema

  defschema %{
    type: :object,
    properties: %{
      name: %{type: :string},
      titles: %{type: :array, items: %{type: :string}}
    },
    required: [:name, :titles]
  }
end
