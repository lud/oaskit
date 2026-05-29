defmodule Oaskit.TestWeb.Schemas.CreatePotionBody do
  @moduledoc false

  use JSV.Schema

  defschema %{
    "type" => "object",
    "properties" => %{
      name: %{"type" => "string"},
      ingredients: %{
        "type" => "array",
        "items" => %{"$ref" => "#/components/schemas/Ingredient"}
      }
    },
    "required" => [:name, :ingredients]
  }
end
