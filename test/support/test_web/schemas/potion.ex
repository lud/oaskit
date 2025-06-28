defmodule OpenApify.TestWeb.Schemas.Potion do
  require(JSV).defschema(%{
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
  })
end
