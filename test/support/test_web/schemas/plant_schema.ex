defmodule Oaskit.TestWeb.Schemas.PlantSchema do
  alias Oaskit.TestWeb.Schemas.SoilSchema
  use JSV.Schema

  @moduledoc false

  defschema %{
    type: :object,
    title: "PlantSchema",
    description: "A plant and the conditions it needs to grow.",
    properties: %{
      name: non_empty_string(),
      sunlight: string_enum_to_atom([:full_sun, :partial_sun, :bright_indirect, :darnkness]),
      soil: SoilSchema
    },
    required: [:name, :sunlight]
  }
end
