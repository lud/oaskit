defmodule Oaskit.TestWeb.Schemas.RespSchema do
  @moduledoc false

  require(JSV).defschema(%{
    type: :object,
    properties: %{op_id: %{type: :string}},
    required: [:op_id]
  })
end
