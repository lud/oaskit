defmodule Oaskit.TestWeb.Schemas.CreatePotionBody do
  require(JSV).defschema(%{
    "type" => "object",
    "properties" => %{
      name: %{"type" => "string"},
      ingredients: %{
        "type" => "array",
        "items" => %{"$ref" => "#/components/schemas/Ingredient"}
      }
    },
    "required" => [:name, :ingredients]
  })
end
