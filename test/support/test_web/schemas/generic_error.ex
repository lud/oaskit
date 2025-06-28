defmodule Oaskit.TestWeb.Schemas.GenericError do
  require(JSV).defschema(%{
    type: :object,
    properties: %{
      errcode: %{type: :integer},
      message: %{type: :string}
    },
    required: [:errcode, :message]
  })
end
