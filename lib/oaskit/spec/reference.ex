defmodule Oaskit.Spec.Reference do
  use JSV.Schema

  @moduledoc """
  Representation of the
  [Reference Object](https://spec.openapis.org/oas/v3.1.1.html#reference-object)
  in OpenAPI Specification.
  """

  @derive {Inspect, optional: [:summary, :description]}

  @doc "Returns the JSON schema for this specification entity."
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
