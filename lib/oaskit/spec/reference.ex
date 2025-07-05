defmodule Oaskit.Spec.Reference do
  use JSV.Schema

  # Allows referencing other components in the OpenAPI Description.
  defschema %{
    title: "Reference",
    type: :object,
    description:
      "Allows referencing other components in the OpenAPI Description using a URI, with optional summary and description overrides.",
    properties: %{
      "$ref": %{
        type: :string,
        description: "Reference identifier in the form of a URI. Required."
      },
      summary: %{
        type: :string,
        description: "A summary that should override the referenced component's summary."
      },
      description: %{
        type: :string,
        description: "A description that should override the referenced component's description."
      }
    },
    additionalProperties: false,
    required: [:"$ref"]
  }
end
