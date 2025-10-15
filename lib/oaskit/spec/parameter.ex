defmodule Oaskit.Spec.Parameter do
  alias Oaskit.Spec.Reference
  import Oaskit.Internal.ControllerBuilder
  use Oaskit.Internal.SpecObject

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
        string_enum_to_atom(
          [:query, :header, :path, :cookie],
          description:
            "The location of the parameter. Allowed values: query, header, path, cookie. Required."
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
    |> format_array_parameter_name_for_openapi()
    |> collect()
  end

  # Format array query parameter names with brackets for OpenAPI spec output.
  # This ensures OpenAPI spec compliance while keeping internal validation clean.
  #
  # The OpenAPI 3.x standard expects array query parameters to be named with
  # brackets (e.g., "colors[]") when style=form and explode=true, which is the
  # default for query parameters. However, Phoenix/Plug removes these brackets
  # during query parameter parsing, so internally we need clean names.
  #
  # This function runs during spec normalization to add brackets to array query
  # parameter names for the final OpenAPI document output.
  defp format_array_parameter_name_for_openapi(%{out: out} = normalizer) do
    name_entry = Enum.find(out, fn {key, _value} -> key == "name" end)
    in_entry = Enum.find(out, fn {key, _value} -> key == "in" end)
    schema_entry = Enum.find(out, fn {key, _value} -> key == "schema" end)

    case {name_entry, in_entry, schema_entry} do
      {{"name", name}, {"in", "query"}, {"schema", schema}} when is_binary(name) ->
        if is_array_schema?(schema) and not String.ends_with?(name, "[]") do
          # Replace the name entry with bracketed version
          new_out =
            Enum.map(out, fn
              {"name", ^name} -> {"name", name <> "[]"}
              other -> other
            end)

          %{normalizer | out: new_out}
        else
          normalizer
        end

      _ ->
        normalizer
    end
  end

  defp is_array_schema?(%{"type" => "array"}) do
    true
  end

  defp is_array_schema?(%{type: :array}) do
    true
  end

  defp is_array_schema?(_) do
    false
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
