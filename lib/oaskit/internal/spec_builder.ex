defmodule Oaskit.Internal.SpecBuilder do
  alias JSV.Builder
  alias JSV.Cast
  alias JSV.Key
  alias JSV.Ref
  alias JSV.RNS
  alias Oaskit.Spec.Operation
  alias Oaskit.Spec.Parameter
  alias Oaskit.Spec.PathItem
  alias Oaskit.Spec.Reference
  alias Oaskit.Spec.RequestBody
  alias Oaskit.Spec.Response

  @moduledoc false

  def build_operations(normal_spec, opts) when is_map(opts) do
    spec = Oaskit.SpecValidator.validate!(normal_spec)

    to_build = stream_operations(spec)

    jsv_ctx = JSV.build_init!(opts.jsv_opts)
    {_root_ns, _, jsv_ctx} = JSV.build_add!(jsv_ctx, normal_spec)

    {validations_by_op_id, jsv_ctx} =
      Enum.map_reduce(to_build, jsv_ctx, fn {rev_path, op_id, op, pathitem_parameters}, jsv_ctx ->
        {validation, jsv_ctx} =
          build_op_validation(rev_path, op, pathitem_parameters, spec, jsv_ctx, opts)

        security = build_op_security(rev_path, op, spec, opts)
        {{op_id, %{security: security, validation: validation}}, jsv_ctx}
      end)

    jsv_root = JSV.to_root!(jsv_ctx, :root)

    {to_ops_map(validations_by_op_id), jsv_root}
  end

  defp stream_operations(spec) do
    Stream.flat_map(spec.paths, fn {path, path_item} ->
      path_item
      |> deref(PathItem, [path, "paths"], spec)
      |> then(fn {path_item, rev_path} ->
        pathitem_parameters = pathitem_parameters(path_item, rev_path, spec)
        buildable_operations(path_item, rev_path, pathitem_parameters)
      end)
    end)
  end

  defp buildable_operations(path_item, rev_path, pathitem_parameters) do
    Stream.map(path_item, fn {verb, operation} ->
      %Operation{operationId: operation_id} = operation
      {[verb | rev_path], operation_id, operation, pathitem_parameters}
    end)
  end

  defp deref(%Reference{"$ref": "#/" <> bin_path = full_path}, expected, _rev_path, spec) do
    {object, rev_path} = resolve_ref(spec, String.split(bin_path, "/"), [])

    case object do
      %^expected{} = found ->
        {found, rev_path}

      other ->
        raise "could not dereference #{inspect(full_path)} (using #{inspect(:lists.reverse(rev_path))}), " <>
                "expected struct #{inspect(expected)}, found #{inspect(other)}"
    end
  end

  defp deref(%mod{} = object, mod, rev_path, _spec) do
    {object, rev_path}
  end

  defp deref(nil, _, rev_path, _spec) do
    {nil, rev_path}
  end

  # When resolving a reference into the spec, if the spec is a struct then we
  # cast the path segment to an atom. Otherwise we keep it as string.
  defp resolve_ref(%_struct{} = object, [h | t], acc) do
    h = String.to_existing_atom(h)
    resolve_ref(Map.fetch!(object, h), t, [h | acc])
  end

  defp resolve_ref(%{} = object, [h | t], acc) do
    resolve_ref(Map.fetch!(object, h), t, [h | acc])
  end

  defp resolve_ref(%{} = maybe_struct, [], acc) do
    {maybe_struct, acc}
  end

  defp pathitem_parameters(path_item, rev_path, spec) do
    case path_item.parameters do
      nil ->
        []

      [] ->
        []

      ps ->
        ps
        |> Enum.with_index()
        |> Enum.map(fn {p, index} ->
          {_parameter, _rev_path} = deref(p, Parameter, [{:index, index} | rev_path], spec)
        end)
    end
  end

  defp to_ops_map(ops_list) do
    Enum.reduce(ops_list, %{}, fn
      {op_id, _}, acc when is_map_key(acc, op_id) ->
        raise ArgumentError,
              "duplicate operation id #{inspect(op_id)} or operation missing the :method option"

      {op_id, op_spec}, acc ->
        Map.put(acc, op_id, op_spec)
    end)
  end

  # -- Validation -------------------------------------------------------------

  defp build_op_validation(rev_path, op, pathitem_parameters, spec, jsv_ctx, opts) do
    validations = []

    # Body

    {validations, jsv_ctx} =
      case build_body_validation(op.requestBody, ["requestBody" | rev_path], spec, jsv_ctx) do
        {:no_validation, jsv_ctx} ->
          {validations, jsv_ctx}

        {required?, body_validations, jsv_ctx} ->
          {[{:body, required?, body_validations} | validations], jsv_ctx}
      end

    # Parameters

    {validations, jsv_ctx} =
      case build_parameters_validation(
             op.parameters,
             pathitem_parameters,
             rev_path,
             spec,
             jsv_ctx
           ) do
        {[], jsv_ctx} ->
          {validations, jsv_ctx}

        {parameters_by_location, jsv_ctx} ->
          {[{:parameters, parameters_by_location} | validations], jsv_ctx}
      end

    # Responses

    {validations, jsv_ctx} =
      if opts.responses do
        {resp_validations, jsv_ctx} =
          build_responses_validations(op.responses, rev_path, spec, jsv_ctx)

        {[{:responses, resp_validations} | validations], jsv_ctx}
      else
        {validations, jsv_ctx}
      end

    {validations, jsv_ctx}
  end

  # -- Body Validation --------------------------------------------------------

  defp build_body_validation(%RequestBody{} = req_body, rev_path, _spec, jsv_ctx)
       when is_map(req_body) do
    {matchers, jsv_ctx} =
      req_body.content
      |> sorted_media_type_clauses()
      |> Enum.map_reduce(jsv_ctx, fn
        {original_media_type, media_matcher, media_spec}, jsv_ctx ->
          case media_spec do
            %{schema: true} ->
              {{media_matcher, :no_validation}, jsv_ctx}

            %{schema: nil} ->
              {{media_matcher, :no_validation}, jsv_ctx}

            %{schema: _schema} ->
              {schema, jsv_ctx} =
                build_schema_key(
                  ["schema", original_media_type, "content" | rev_path],
                  jsv_ctx
                )

              {{media_matcher, schema}, jsv_ctx}

            _ ->
              {{media_matcher, :no_validation}, jsv_ctx}
          end
      end)

    {req_body.required, matchers, jsv_ctx}
  end

  defp build_body_validation(%Reference{} = ref, rev_path, spec, jsv_ctx) do
    {request_body, body_rev_path} = deref(ref, RequestBody, rev_path, spec)
    build_body_validation(request_body, body_rev_path, spec, jsv_ctx)
  end

  defp build_body_validation(nil, _rev_path, _spec, jsv_ctx) do
    {:no_validation, jsv_ctx}
  end

  defp sorted_media_type_clauses(content_map) do
    content_map
    |> Enum.map(fn {media_type, media_spec} ->
      matcher = media_type_to_matcher(media_type)
      {media_type, matcher, media_spec}
    end)
    |> sort_media_type_clauses()
  end

  defp media_type_to_matcher(media_type) when is_binary(media_type) do
    case Plug.Conn.Utils.media_type(media_type) do
      :error -> {media_type, ""}
      {:ok, primary, secondary, _} -> {primary, secondary}
    end
  end

  defp sort_media_type_clauses(list) do
    Enum.sort_by(list, fn {_, {primary, secondary}, _} ->
      {media_priority(primary), media_priority(secondary), primary, secondary}
    end)
  end

  defp media_priority(type) do
    case type do
      "*" -> 2
      "" -> 1
      t when is_binary(t) -> 0
    end
  end

  # -- Parameters Validation --------------------------------------------------

  defp build_parameters_validation([], [], _rev_path, _spec, jsv_ctx) do
    {[], jsv_ctx}
  end

  defp build_parameters_validation(nil, [], _rev_path, _spec, jsv_ctx) do
    {[], jsv_ctx}
  end

  # _wrev means "with rev path"
  defp build_parameters_validation(parameters, pathitem_parameters_wrev, rev_path, spec, jsv_ctx) do
    parameters_wrev =
      parameters
      |> Enum.with_index()
      |> Enum.map(fn {p_or_ref, index} ->
        deref(p_or_ref, Parameter, [{:index, index}, "parameters" | rev_path], spec)
      end)

    # We need to keep only pathitem parameters that are not overriden by the
    # operation.
    defined_by_op =
      Map.new(parameters_wrev, fn {%{name: name, in: loc}, _} -> {{name, loc}, true} end)

    pathitem_parameters_wrev =
      Enum.filter(pathitem_parameters_wrev, fn {%{name: name, in: loc}, _} ->
        not Map.has_key?(defined_by_op, {name, loc})
      end)

    all_parameters_wrev = pathitem_parameters_wrev ++ parameters_wrev

    {built_params, jsv_ctx} =
      Enum.flat_map_reduce(
        all_parameters_wrev,
        jsv_ctx,
        fn
          {%Parameter{in: p_in} = parameter, rev_path}, jsv_ctx when p_in in [:path, :query] ->
            {built_param, jsv_ctx} =
              build_parameter_validation(parameter, rev_path, jsv_ctx)

            {[built_param], jsv_ctx}

          {%Parameter{}, _}, jsv_ctx ->
            {[], jsv_ctx}
        end
      )

    built_params =
      built_params
      |> Enum.group_by(& &1.in)
      |> Enum.into(%{path: [], query: []})

    {built_params, jsv_ctx}
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp build_parameter_validation(parameter, rev_path, jsv_ctx) do
    key = String.to_atom(parameter.name)

    {schema_key, jsv_ctx} =
      case parameter do
        %{schema: true} -> {:no_validation, jsv_ctx}
        %{schema: nil} -> {:no_validation, jsv_ctx}
        %{schema: schema} -> build_parameter_schema(schema, ["schema" | rev_path], jsv_ctx)
        _ -> {:no_validation, jsv_ctx}
      end

    built = %{
      bin_key: parameter.name,
      key: key,
      required: parameter_required(parameter),
      schema_key: schema_key,
      in: parameter.in
    }

    {built, jsv_ctx}
  end

  defp parameter_required(%Parameter{required: req?}) when is_boolean(req?) do
    req?
  end

  defp parameter_required(%Parameter{in: p_in}) do
    case p_in do
      :path -> true
      :query -> false
    end
  end

  defp build_parameter_schema(schema, rev_path, jsv_ctx) do
    # schema is already defined in the JSV build context, it is not given to the
    # builder. But it is used to check if we need to precast the values, as
    # params are always received as strings.
    precast = parameter_precast(schema, rev_path, :root, jsv_ctx)
    {jsv_key, jsv_ctx} = build_schema_key(rev_path, jsv_ctx)

    final_validator =
      case precast do
        {:precast, caster} -> {:precast, caster, jsv_key}
        :noprecast -> jsv_key
      end

    {final_validator, jsv_ctx}
  end

  defp parameter_precast(schema, rev_path, ns, jsv_ctx) do
    case schema do
      %{"type" => "integer"} ->
        {:precast, &Cast.string_to_integer/1}

      %{"type" => "boolean"} ->
        {:precast, &Cast.string_to_boolean/1}

      %{"type" => "number"} ->
        {:precast, &Cast.string_to_number/1}

      %{"type" => "array", "items" => %{"type" => "integer"}} ->
        {:precast, {:list, &Cast.string_to_integer/1}}

      %{"type" => "array", "items" => %{"type" => "boolean"}} ->
        {:precast, {:list, &Cast.string_to_boolean/1}}

      %{"type" => "array", "items" => %{"type" => "number"}} ->
        {:precast, {:list, &Cast.string_to_number/1}}

      %{"$ref" => _} = subschema ->
        parameter_precast_ref(subschema, rev_path, ns, jsv_ctx)

      _ ->
        :noprecast
    end
  end

  # If we want to support fetching parameters from refs we need to do it the
  # right way, _i.e_ JSV having support for fetching a ref recursively with NS
  # management, until we find a %{"type" => _} or no "$ref" anymore.
  #
  # The code below works but it does belong to JSV. For now this library does
  # not support precasting complex parameters and the users should expect a
  # string and do complex stuff on their side.
  #
  # I'm leaving the code as-is but instead of raising or warning we will just
  # silently ignore pre casting.
  #
  # Also JSV needs to expose the build context as a struct, currently we are
  # digging into a private record.
  defp parameter_precast_ref(%{"$ref" => ref} = subschema, rev_path, ns, jsv_ctx) do
    {:ok, sub_ns} =
      case subschema do
        %{"$id" => id} -> RNS.derive(ns, id)
        _ -> {:ok, ns}
      end

    ref = Ref.parse!(ref, sub_ns)
    {:build, builder, jsv_validators} = jsv_ctx
    new_builder = Builder.ensure_resolved!(builder, ref)
    key = Key.of(ref)
    resolved = Builder.fetch_resolved!(builder, key)
    {resolved.raw, sub_ns, {:build, new_builder, jsv_validators}}
  rescue
    _ -> :noprecast
  else
    {new_schema, new_ns, new_jsv_ctx} ->
      parameter_precast(new_schema, rev_path, new_ns, new_jsv_ctx)
  end

  # -- Responses Validation ---------------------------------------------------

  defp build_responses_validations(responses, rev_path, spec, jsv_ctx) do
    {validations, jsv_ctx} =
      Enum.map_reduce(responses, jsv_ctx, fn {code_str, resp_or_ref}, jsv_ctx ->
        {response, rev_path} =
          deref(resp_or_ref, Response, [code_str, "responses" | rev_path], spec)

        code = cast_response_code(code_str)
        {resp_validation, jsv_ctx} = build_response_validation(response, rev_path, jsv_ctx)
        {{code, resp_validation}, jsv_ctx}
      end)

    {Map.new(validations), jsv_ctx}
  end

  defp cast_response_code("default") do
    :default
  end

  defp cast_response_code(code) do
    String.to_integer(code)
  end

  defp build_response_validation(%{content: nil}, _rev_path, jsv_ctx) do
    {:no_validation, jsv_ctx}
  end

  defp build_response_validation(response, rev_path, jsv_ctx) do
    {matchers, jsv_ctx} =
      response.content
      |> sorted_media_type_clauses()
      |> Enum.map_reduce(jsv_ctx, fn
        {original_media_type, media_matcher, media_spec}, jsv_ctx ->
          case media_spec do
            %{schema: true} ->
              {{media_matcher, :no_validation}, jsv_ctx}

            %{schema: nil} ->
              {{media_matcher, :no_validation}, jsv_ctx}

            %{schema: _schema} ->
              {schema, jsv_ctx} =
                build_schema_key(
                  ["schema", original_media_type, "content" | rev_path],
                  jsv_ctx
                )

              {{media_matcher, schema}, jsv_ctx}

            _ ->
              {{media_matcher, :no_validation}, jsv_ctx}
          end
      end)

    {matchers, jsv_ctx}
  end

  # -- Security ---------------------------------------------------------------

  # TODO global inherited security
  defp build_op_security(_rev_path, op, _spec, _opts) do
    op.security
  end

  # -- Helpers ----------------------------------------------------------------

  defp build_schema_key(rev_path, jsv_ctx) do
    ref = rev_path_to_ref(rev_path, [])
    {_schema_key, _jsv_ctx} = JSV.build_key!(jsv_ctx, ref)
  end

  # Reverse the reversed path and ensure all keys are strings. This is
  # especially useful when dealing with references to the responses, as they are
  # under a numeric string key (like "200", "404", etc.).
  #
  # Parameters are true indexes, we have a special tuple for those.
  defp rev_path_to_ref([{:index, i} | t], acc) when is_integer(i) do
    rev_path_to_ref(t, [i | acc])
  end

  defp rev_path_to_ref([h | t], acc) when is_binary(h) do
    rev_path_to_ref(t, [h | acc])
  end

  defp rev_path_to_ref([h | t], acc) when is_atom(h) do
    rev_path_to_ref(t, [Atom.to_string(h) | acc])
  end

  defp rev_path_to_ref([], acc) do
    Ref.pointer!(acc, :root)
  end
end
