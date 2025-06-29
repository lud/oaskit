defmodule Oaskit.TestWeb.Schemas.GenericError do
  @moduledoc false

  require(JSV).defschema(%{
    type: :object,
    properties: %{
      errcode: %{type: :integer},
      message: %{type: :string}
    },
    required: [:errcode, :message]
  })
end
