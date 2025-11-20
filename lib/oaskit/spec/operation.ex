defmodule Oaskit.Spec.Operation do
  alias Oaskit.Spec.Parameter
  alias Oaskit.Spec.Reference
  alias Oaskit.Spec.RequestBody
  alias Oaskit.Spec.Response
  import Oaskit.Internal.ControllerBuilder
  use Oaskit.Internal.SpecObject

  @additional_properties :extensions

  defschema %{
    title: "Operation",
    type: :object,
    description: "Describes a single API operation on a path.",
    properties: %{
      tags: %{
        type: :array,
        items: %{type: :string},
        description: "A list of tags for API documentation control."
      },
      summary: %{type: :string, description: "A short summary of what the operation does."},
      description: %{
        type: :string,
        description: "A verbose explanation of the operation behavior."
      },
      externalDocs: Oaskit.Spec.ExternalDocumentation,
      operationId: %{
        type: :string,
        description: "A unique string used to identify the operation."
      },
      parameters: %{
        type: :array,
        items: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Parameter]},
        description: "A list of parameters applicable for this operation."
      },
      requestBody: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.RequestBody]},
      responses: Oaskit.Spec.Responses,
      callbacks: %{
        type: :object,
        additionalProperties: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Callback]},
        description: "A map of possible out-of-band callbacks related to the parent operation."
      },
      deprecated: %{type: :boolean, description: "Declares this operation to be deprecated."},
      security: %{
        type: :array,
        items: Oaskit.Spec.SecurityRequirement,
        description: "A list of security mechanisms that can be used for this operation."
      },
      servers: %{
        type: :array,
        items: Oaskit.Spec.Server,
        description: "Alternative servers array for this operation."
      }
    },
    required: [:responses, :operationId]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([:tags, :summary, :description, :operationId, :deprecated])
    |> normalize_subs(
      callbacks: {:list, {:or_ref, Oaskit.Spec.Callback}},
      externalDocs: Oaskit.Spec.ExternalDocumentation,
      parameters: {:list, {:or_ref, Oaskit.Spec.Parameter}},
      requestBody: {:or_ref, Oaskit.Spec.RequestBody},
      responses: Oaskit.Spec.Responses,
      security: {:list, Oaskit.Spec.SecurityRequirement},
      servers: {:list, Oaskit.Spec.Server}
    )
    # collect extensions added by the operation macro
    |> normalize_splat(:extensions, &normalize_extensions/2)
    # This will collect leftover keys when the data was a raw map
    |> collect()
  end

  defp normalize_extensions(map, ctx) when map_size(map) == 0 do
    {[], ctx}
  end

  defp normalize_extensions(_map, %{spec_module: nil} = ctx) do
    {[], ctx}
  end

  defp normalize_extensions(map, %{spec_module: mod} = ctx) when is_map(map) do
    private_extensions? = ctx.private_extensions?

    pairs =
      Enum.flat_map(map, fn pair ->
        case mod.dump_extension(pair) do
          {"x-" <> _ = bin_key, _} = new_pair when is_binary(bin_key) -> [new_pair]
          {bin_key, _} = new_pair when is_binary(bin_key) and private_extensions? -> [new_pair]
          {bin_key, _} when is_binary(bin_key) -> []
          nil -> []
          other -> exit({:bad_return_value, other})
        end
      end)

    {pairs, ctx}
  end

  def from_controller!(spec, opts \\ [])

  def from_controller!(%Reference{} = ref, _) do
    ref
  end

  def from_controller!(spec, opts) do
    shared_tags = Keyword.get(opts, :shared_tags, [])

    spec
    |> make(__MODULE__)
    |> rename_input(:operation_id, :operationId)
    |> rename_input(:request_body, :requestBody)
    |> take_required(:operationId)
    |> take_default(:tags, nil, &merge_tags(&1, shared_tags))
    |> take_default(:parameters, nil, &cast_params(&1, opts))
    |> take_default(:description, nil)
    |> take_default(:callbacks, nil)
    |> take_default(:deprecated, nil)
    |> take_default(:servers, nil)
    |> take_default(:externalDocs, nil)
    |> take_required(:responses, &cast_responses/1)
    |> take_default(:security, nil, &cast_security/1)
    |> take_default(:summary, nil)
    |> take_default(
      :requestBody,
      nil,
      {&RequestBody.from_controller/1, "invalid request body"}
    )
    |> collect_leftovers(:extensions)
    |> into()
  end

  defp cast_params(parameters, opts) when is_map(parameters) do
    cast_params(Map.to_list(parameters), opts)
  end

  defp cast_params(parameters, opts) when is_list(parameters) do
    if not Keyword.keyword?(parameters) do
      raise ArgumentError, "expected parameters to be a keyword list or map"
    end

    shared_parameters = Keyword.get(opts, :shared_parameters, [])

    {parameters, defined_by_op} =
      Enum.map_reduce(parameters, [], fn {k, p}, locals ->
        case Parameter.from_controller!(k, p) do
          %Parameter{name: name, in: loc} = param ->
            {param, [{{name, loc}, true} | locals]}

          %Reference{} = ref ->
            maybe_warn_parameter_reference(k, p, opts)

            {ref, locals}
        end
      end)

    defined_by_op = Map.new(defined_by_op)

    # We need to merge shared parameters

    add_parameters =
      Enum.filter(shared_parameters, fn %{name: name, in: loc} when is_binary(name) ->
        not Map.has_key?(defined_by_op, {name, loc})
      end)

    {:ok, parameters ++ add_parameters}
  end

  defp cast_params(other, _) do
    raise ArgumentError,
          "invalid parameters, expected a map, list or keyword list, got: #{inspect(other)}"
  end

  defp maybe_warn_parameter_reference(k, p, opts) do
    case k do
      :_ -> :ok
      _ -> warn_parameter_reference(k, p, opts)
    end
  end

  defp warn_parameter_reference(k, p, opts) do
    controller = Keyword.fetch!(opts, :controller)
    action = Keyword.fetch!(opts, :action)

    IO.warn(
      "It is not possible to change a parameter name to #{inspect(k)} " <>
        "with the operation macro in #{inspect(controller)} " <>
        "when using a reference.\n" <>
        "Please define the parameter with the :_ key to suppress this warning:\n" <>
        """

            operation, #{inspect(action)},
              # ...
              parameters: [
                _: #{inspect(p)}
              ]
        """
    )
  end

  defp cast_responses(responses) when is_map(responses) do
    cast_responses(Map.to_list(responses))
  end

  defp cast_responses([]) do
    raise ArgumentError, "empty responses list or map"
  end

  defp cast_responses(responses) when is_list(responses) do
    normal =
      Map.new(responses, fn
        # We do not reject unknown integer status codes, this could be blocking
        # for users with special needs.
        {code, resp} when is_integer(code) ->
          {code, Response.from_controller!(resp)}

        {code, resp} ->
          {response_code!(code), Response.from_controller!(resp)}

        other ->
          raise ArgumentError,
                "invalid value in :responses, expected a map or keyword list, got item: #{inspect(other)}"
      end)

    {:ok, normal}
  end

  defp cast_responses(other) do
    raise ArgumentError,
          "operation macro expects a map or list of responses, got: #{inspect(other)}"
  end

  defp response_code!(:default) do
    :default
  end

  defp response_code!(status) do
    Plug.Conn.Status.code(status)
  rescue
    _ ->
      reraise ArgumentError,
              "invalid status given to :responses, got: #{inspect(status)}",
              __STACKTRACE__
  end

  defp cast_security(nil) do
    {:ok, nil}
  end

  defp cast_security(security) when is_list(security) do
    sec =
      Enum.map(security, fn map when is_map(map) ->
        Map.new(map, fn
          {scheme, scopes} when is_binary(scheme) and is_list(scopes) ->
            {scheme, cast_scopes(scopes)}

          {scheme, scopes} when is_atom(scheme) and is_list(scopes) ->
            {Atom.to_string(scheme), cast_scopes(scopes)}

          _other ->
            raise_invalid_security(security)
        end)
      end)

    {:ok, sec}
  end

  defp cast_security(other) do
    raise_invalid_security(other)
  end

  defp cast_scopes(scopes) do
    Enum.map(scopes, fn
      s when is_binary(s) -> s
      s when is_atom(s) -> Atom.to_string(s)
      _ -> raise_invalid_security(scopes)
    end)
  end

  @spec raise_invalid_security(term) :: no_return()
  defp raise_invalid_security(security) do
    raise ArgumentError,
          "operation macro expects :security to be a list of maps with scope lists as values, got: #{inspect(security)}"
  end

  defp merge_tags(self_tags, shared_tags) do
    {:ok, Enum.uniq(self_tags ++ shared_tags)}
  end
end
