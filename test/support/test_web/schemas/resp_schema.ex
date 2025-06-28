defmodule OpenApify.TestWeb.Schemas.RespSchema do
  require(JSV).defschema(%{
    type: :object,
    properties: %{op_id: %{type: :string}},
    required: [:op_id]
  })
end
