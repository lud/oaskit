defmodule Oaskit.TestWeb.Schemas.Potion do
  use JSV.Schema
  @moduledoc false

  @derive Jason.Encoder

  defschema %{
    "type" => "object",
    "properties" => %{
      id: %{"type" => "string"},
      name: %{"type" => "string"},
      ingredients: %{
        "type" => "array",
        "items" => %{"$ref" => "#/components/schemas/Ingredient"}
      },
      brewingTime: %{"type" => "integer"}
    },
    "required" => [:id, :name, :ingredients]
  }
end
