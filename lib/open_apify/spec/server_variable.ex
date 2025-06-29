defmodule OpenApify.Spec.ServerVariable do
  import JSV
  use OpenApify.Internal.SpecObject

  # Object representing a server variable for server URL template substitution.
  defschema %{
    title: "ServerVariable",
    type: :object,
    description: "Object representing a server variable for server URL template substitution.",
    properties: %{
      enum: %{
        type: :array,
        items: %{type: :string},
        description: "Enumeration of string values for substitution options from a limited set."
      },
      default: %{
        type: :string,
        description: "The default value to use for substitution. Required."
      },
      description: %{
        type: :string,
        description: "An optional description for the server variable."
      }
    },
    required: [:default]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default(:all)
    |> collect()
  end
end
