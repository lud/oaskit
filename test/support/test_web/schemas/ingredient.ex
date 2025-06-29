defmodule Oaskit.TestWeb.Schemas.Ingredient do
  @moduledoc false

  require(JSV).defschema(%{
    "type" => "object",
    "properties" => %{
      name: %{"type" => "string"},
      quantity: %{"type" => "integer"},
      unit: %{
        "type" => "string",
        "enum" => ["pinch", "dash", "scoop", "whiff", "nub"]
      }
    },
    "required" => [:name, :quantity, :unit]
  })
end
