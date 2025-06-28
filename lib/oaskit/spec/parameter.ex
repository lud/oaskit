defmodule Oaskit.Spec.Parameter do
  alias Oaskit.Spec.Reference
  import Oaskit.Internal.ControllerBuilder
  import JSV
  use Oaskit.Internal.SpecObject

  # Describes a single operation parameter.
  defschema %{
    title: "Parameter",
    type: :object,
    description: "Describes a single operation parameter.",
    properties: %{
      name: %{
        type: :string,
        description: "The name of the parameter. Required."
      },
      in:
        JSV.Schema.string_to_atom_enum(
          %{
            description:
              "The location of the parameter. Allowed values: query, header, path, cookie. Required."
          },
          [
            :query,
            :header,
            :path,
            :cookie
          ]
        ),
      description: %{type: :string, description: "A brief description of the parameter."},
      required: %{type: :boolean, description: "Determines whether this parameter is mandatory."},
      deprecated: %{type: :boolean, description: "Specifies that the parameter is deprecated."},
      # TODO(doc): Not supported for now, add in roadmap and allow parsing
      #
      # allowEmptyValue: %{
      #   type: :boolean,
      #   description: "Sets the ability to pass empty-valued parameters."
      # },
      # style:
      #   JSV.Schema.string_to_atom_enum(
      #     %{
      #       description:
      #         "Describes how the parameter value will be serialized. See OpenAPI spec for allowed values.",
      #         "default": :simple
      #     },
      #     [
      #       :matrix,
      #       :label,
      #       :form,
      #       :simple,
      #       :spaceDelimited,
      #       :pipeDelimited,
      #       :deepObject
      #     ]
      #   ),
      # explode: %{
      #   type: :boolean,
      #   description: "When true, array or object values generate separate parameters."
      # },
      allowReserved: %{
        type: :boolean,
        description: "Allows reserved characters in parameter values."
      },
      schema: Oaskit.Spec.SchemaWrapper,
      examples: %{
        type: :object,
        additionalProperties: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Example]},
        description: "Examples of the parameter's potential value."
      }
      # content: %{
      #   type: :object,
      #   additionalProperties: Oaskit.Spec.MediaType,
      #   description: "A map containing parameter representations for different media types."
      # }
    },
    required: [:name, :in]
  }

  # TODO(doc) content is not supported, always use schema

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([
      :name,
      :in,
      :description,
      :required,
      :deprecated,
      :explode,
      :allowReserved,
      :examples
    ])
    |> normalize_schema(:schema)
    |> skip(:content)
    |> collect()
  end

  def from_controller!(_name, %Reference{} = ref) do
    ref
  end

  def from_controller!(name, spec) when is_atom(name) and is_list(spec) do
    spec
    |> make(__MODULE__)
    |> put(:name, name)
    |> take_required(:in, &validate_location/1)
    |> take_default(:schema, _boolean_schema = true)
    |> take_default_lazy(:required, fn -> Access.fetch(spec, :in) == {:ok, :path} end)
    |> take_default_lazy(:examples, fn ->
      case Access.fetch(spec, :example) do
        {:ok, example} -> [example]
        :error -> nil
      end
    end)
    |> into()
  end

  defp validate_location(loc) do
    if loc in [:path, :query] do
      {:ok, loc}
    else
      {:error, "parameter :in only supports :path and :query"}
    end
  end
end
