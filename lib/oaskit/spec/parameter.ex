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
      style:
        string_enum_to_atom_or_nil(
          [
            :matrix,
            :label,
            :form,
            :simple,
            :spaceDelimited,
            :pipeDelimited,
            :deepObject
          ],
          description:
            "Describes how the parameter value will be serialized. See OpenAPI spec for allowed values."
        ),
      explode: %{
        type: :boolean,
        description: "When true, array or object values generate separate parameters."
      },
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
      :allowReserved,
      :deprecated,
      :description,
      :examples,
      :explode,
      :in,
      :name,
      :required,
      :style
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
    |> put(:name, to_string(name))
    |> take_required(:in, &validate_location/1)
    |> take_default(:schema, _boolean_schema = true, &ensure_schema/1)
    |> take_default(:explode, nil)
    |> take_default(:style, nil)
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
    if loc in [:path, :query, :header] do
      {:ok, loc}
    else
      {:error, "parameter :in only supports :path, :query and :header"}
    end
  end

  @doc """
  Returns the given parameter with the expected default values for style and
  explode.

  Default style are:

  * `:form` for query and cookie parameters
  * `:simple` for header and path parameters

  Default explode is `true` when the style is `:form`, `false` otherwise.

  See [the
  specifications](https://spec.openapis.org/oas/v3.1.2.html#parameter-object)
  for more information.
  """
  def with_defaults(%__MODULE__{} = parameter) do
    %{in: loc, style: style, explode: explode?} = parameter

    style =
      if is_nil(style) do
        parameter_default_style(loc)
      else
        style
      end

    explode? =
      if is_nil(explode?) do
        parameter_default_explode?(style)
      else
        explode?
      end

    %{parameter | style: style, explode: explode?}
  end

  defp parameter_default_style(param_in) do
    case param_in do
      :query -> :form
      :cookie -> :form
      :path -> :simple
      :header -> :simple
    end
  end

  defp parameter_default_explode?(param_style) do
    case param_style do
      :form -> true
      other when is_atom(other) -> false
    end
  end
end
