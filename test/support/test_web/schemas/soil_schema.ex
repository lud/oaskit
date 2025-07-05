defmodule Oaskit.TestWeb.Schemas.SoilSchema do
  use JSV.Schema

  @moduledoc false

  defschema %{
    type: :object,
    properties: %{
      acid: boolean(),
      density: number()
    },
    required: [:acid, :density]
  }
end
