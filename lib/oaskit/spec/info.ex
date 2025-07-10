defmodule Oaskit.Spec.Info do
  use Oaskit.Internal.SpecObject

  defschema %{
    title: "Info",
    type: :object,
    description: "Metadata about the API.",
    properties: %{
      title: %{type: :string, description: "The title of the API. Required."},
      summary: %{type: :string, description: "A short summary of the API's purpose."},
      description: %{type: :string, description: "A detailed description of the API."},
      termsOfService: %{type: :string, description: "A URI for the Terms of Service for the API."},
      contact: Oaskit.Spec.Contact,
      license: Oaskit.Spec.License,
      version: %{type: :string, description: "The version of the OpenAPI document. Required."}
    },
    required: [:title, :version]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      contact: Oaskit.Spec.Contact,
      license: Oaskit.Spec.License
    )
    |> normalize_default(:all)
    |> collect()
  end
end
