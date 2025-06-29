defmodule Oaskit.TestWeb.Schemas.SoilSchema do
  @moduledoc false

  alias JSV.Schema

  require(JSV).defschema(%{
    type: :object,
    properties: %{
      acid: Schema.boolean(),
      density: Schema.number()
    },
    required: [:acid, :density]
  })
end
