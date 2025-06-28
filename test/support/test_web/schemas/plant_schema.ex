defmodule Oaskit.TestWeb.Schemas.PlantSchema do
  alias JSV.Schema
  alias Oaskit.TestWeb.Schemas.SoilSchema

  require(JSV).defschema(%{
    type: :object,
    title: "PlantSchema",
    properties: %{
      name: Schema.non_empty_string(),
      sunlight:
        Schema.string_to_atom_enum([:full_sun, :partial_sun, :bright_indirect, :darnkness]),
      soil: SoilSchema
    },
    required: [:name, :sunlight]
  })
end
