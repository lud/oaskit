defmodule Oaskit.Internal.Normalizer do
  alias JSV.Helpers.MapExt
  alias JSV.Schema
  alias Oaskit.Errors.NormalizeError
  alias Oaskit.Internal.NormalizationContext
  alias Oaskit.Spec.OpenAPI
  alias Oaskit.Spec.Reference

  @moduledoc false

  @enforce_keys [:data, :sourcemod, :out, :ctx]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}

  @callback normalize!(data :: term, ctx :: NormalizationContext.t()) ::
              {struct, NormalizationContext.t()}

  def normalize!(openapi_spec) when is_map(openapi_spec) do
    # Boostrap normalization by creating a context with all schemas from
    # #/components/schemas normalized.
    {openapi_spec, ctx} = normalize_predef_schemas(openapi_spec)
    {normal, ctx} = normalize!(openapi_spec, OpenAPI, ctx)

    put_in(
      normal,
      [Access.key("components", %{}), Access.key("schemas", %{})],
      ctx.components_schemas
    )
  end

  defp empty_context do
    %NormalizationContext{seen_schema_mods: %{}, components_schemas: %{}, rev_path: []}
  end

  defp normalize_predef_schemas(openapi_spec) do
    with {:ok, "components", {components, rest_spec}} <- pop_normal(openapi_spec, :components),
         {:ok, "schemas", {components_schemas, rest_components}} <-
           pop_normal(components, :schemas) do
      ctx = initialize_context_with_predefs(components_schemas)
      ctx = %{ctx | rev_path: []}

      {Map.put(rest_spec, "components", rest_components), ctx}
    else
      :error -> {openapi_spec, empty_context()}
    end
  end

  defp initialize_context_with_predefs(schemas_map) do
    {predefs, others} =
      Enum.split_with(schemas_map, fn {_refname, schema} ->
        is_atom(schema) and Schema.schema_module?(schema)
      end)

    # Other schemas can be maps, and those maps can contain schema modules that
    # we will normalize. So we need to reserve the refname and mark the schemas
    # as already seen. To do so we will initialize the context with
    # placeholders.
    placeholders = Map.new(schemas_map, fn {k, _} -> {k, :__placeholder__} end)

    # We also mark all the schemas that we will normalize as seen, to avoid
    # building them if present in sub schemas.
    seen = Map.new(predefs, fn {refname, module} -> {module, refname} end)

    # We can boostrap the normalization with that in the context.
    ctx = %NormalizationContext{
      seen_schema_mods: seen,
      components_schemas: placeholders,
      rev_path: ["schemas", "components"]
    }

    # To normalize the module schemas we just have to normalize their exported
    # .json_schema() and replace the placeholder with the result

    ctx =
      Enum.reduce(predefs, ctx, fn {refname, module}, ctx ->
        {normal_schema, ctx} = deep_normalize_schema(Schema.from_module(module), ctx)

        %{
          ctx
          | components_schemas:
              Map.update!(ctx.components_schemas, refname, fn :__placeholder__ ->
                normal_schema
              end)
        }
      end)

    # The raw schemas are easier to normalize
    ctx =
      Enum.reduce(others, ctx, fn {refname, raw_schema}, ctx ->
        {normal_schema, ctx} = deep_normalize_schema(raw_schema, ctx)

        %{
          ctx
          | components_schemas:
              Map.update!(ctx.components_schemas, refname, fn :__placeholder__ ->
                normal_schema
              end)
        }
      end)

    ctx
  end

  def normalize!(data, sourcemod, ctx) do
    sourcemod.normalize!(data, ctx)
  end

  def from(%sourcemod{} = data, sourcemod, ctx) do
    from(MapExt.from_struct_no_nils(data), sourcemod, ctx)
  end

  def from(data, sourcemod, ctx) when is_map(data) and not is_struct(data) do
    %__MODULE__{data: data, sourcemod: sourcemod, ctx: ctx, out: []}
  end

  def from(other, sourcemod, ctx) do
    raise NormalizeError,
      ctx: ctx,
      reason:
        "invalid value when normalizing Open API model #{inspect(sourcemod)}, " <>
          "expected a map or %#{inspect(sourcemod)}{}, got: #{inspect(other)}"
  end

  def normalize_subs(normalizer, [{_, _} | _] = keymap) when is_list(keymap) do
    %__MODULE__{data: data, ctx: ctx, out: outlist} = normalizer

    {data, outlist, ctx} =
      Enum.reduce(keymap, {data, outlist, ctx}, fn {key, caster}, {data, outlist, ctx} = acc ->
        case pop_normal(data, key) do
          {:ok, bin_key, {value, data}} ->
            {cast_value, ctx} = downpath(ctx, bin_key, &apply_caster(value, caster, &1))
            {data, [{bin_key, cast_value} | outlist], ctx}

          :error ->
            acc
        end
      end)

    %{normalizer | data: data, ctx: ctx, out: outlist}
  end

  # accepting a function to handle additional properties
  def normalize_subs(normalizer, caster) when is_function(caster, 2) when is_tuple(caster) do
    %__MODULE__{data: data, ctx: ctx, out: outlist} = normalizer

    {outlist, ctx} =
      data
      |> sort_by_key()
      |> Enum.reduce({outlist, ctx}, fn {key, value}, {outlist, ctx} ->
        bin_key = ensure_binary_key(key)
        {value, ctx} = downpath(ctx, bin_key, &apply_caster(value, caster, &1))
        {[{bin_key, value} | outlist], ctx}
      end)

    %{normalizer | data: %{}, ctx: ctx, out: outlist}
  end

  def normalize_default(normalizer, :all) do
    %__MODULE__{data: data, out: outlist} = normalizer

    outlist =
      Enum.reduce(data, outlist, fn {key, value}, outlist ->
        [{ensure_binary_key(key), to_json_decoded(value)} | outlist]
      end)

    %{normalizer | data: %{}, out: outlist}
  end

  def normalize_default(normalizer, keys) when is_list(keys) do
    normalize_subs(normalizer, Enum.map(keys, &{&1, :default}))
  end

  def normalize_schema(normalizer, key) when is_atom(key) do
    %__MODULE__{data: data, ctx: ctx, out: outlist} = normalizer

    case pop_normal(data, key) do
      {:ok, bin_key, {schema, data}} ->
        {replacement_schema, ctx} = do_normalize_schema(schema, ctx)
        %{normalizer | data: data, ctx: ctx, out: [{bin_key, replacement_schema} | outlist]}

      :error ->
        normalizer
    end
  end

  def skip(normalizer, key) when is_atom(key) do
    %__MODULE__{data: data} = normalizer

    case pop_normal(data, key) do
      {:ok, _bin_key, {_value, data}} -> %{normalizer | data: data}
      :error -> normalizer
    end
  end

  def collect(%__MODULE__{data: data, ctx: ctx, out: outlist}) do
    {extensions, _leftovers} = collect_remaining(data)
    collected = Map.merge(Map.new(extensions), Map.new(outlist))
    {collected, ctx}
  end

  defp collect_remaining(data) do
    {extensions, leftovers} =
      data
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.reduce({_extensions = [], _leftovers = []}, fn
        {"x-" <> _ = key, value}, {exts, left} -> {[{key, to_json_decoded(value)} | exts], left}
        {key, value}, {exts, left} -> {exts, [{key, to_json_decoded(value)} | left]}
      end)

    {extensions, leftovers}
  end

  defp downpath(ctx, key, fun) do
    {retval, ctx} = fun.(push_path(ctx, key))
    {retval, pop_path(ctx)}
  end

  def current_path(ctx) do
    :lists.reverse(ctx.rev_path)
  end

  def push_path(ctx, key) when is_binary(key) when is_integer(key) and key >= 0 do
    %{ctx | rev_path: [key | ctx.rev_path]}
  end

  def pop_path(ctx) do
    %{ctx | rev_path: tl(ctx.rev_path)}
  end

  # pops a key regardless of atom/binary encoding:
  # * If the key is in the map, we pop it
  # * Otherwise if the key is an atom, we try to pop its binary form
  # * If nothing works it's an error
  #
  # The function also returns the binary key
  defp pop_normal(map, key) when is_map_key(map, key) do
    {:ok, to_string(key), Map.pop!(map, key)}
  end

  defp pop_normal(map, key) when is_atom(key) do
    pop_normal(map, Atom.to_string(key))
  end

  defp pop_normal(map, key) when is_integer(key) do
    pop_normal(map, Integer.to_string(key))
  end

  defp pop_normal(_map, key) when is_binary(key) do
    :error
  end

  defp pop_normal(_map, key) do
    raise ArgumentError, "invalid key: #{inspect(key)}"
  end

  defp ensure_binary_key(key) when is_atom(key) do
    Atom.to_string(key)
  end

  defp ensure_binary_key(key) when is_binary(key) do
    key
  end

  defp ensure_binary_key(key) when is_integer(key) do
    Integer.to_string(key)
  end

  defp ensure_binary_key(key) do
    raise ArgumentError, "invalid key: #{inspect(key)}"
  end

  defp apply_caster(data, :default, ctx) do
    {to_json_decoded(data), ctx}
  end

  defp apply_caster(data, fun, ctx) when is_function(fun, 2) do
    fun.(data, ctx)
  end

  defp apply_caster(data, {:list, caster}, ctx) when is_list(data) do
    data
    |> Enum.with_index()
    |> Enum.map_reduce(ctx, fn {item, index}, ctx ->
      downpath(ctx, index, &apply_caster(item, caster, &1))
    end)
  end

  defp apply_caster(data, {:list, _caster}, ctx) do
    raise NormalizeError, ctx: ctx, reason: "expected a list but got: #{inspect(data)}"
  end

  defp apply_caster(data, {:map, caster}, ctx) when is_map(data) do
    {pairs, ctx} =
      data
      # The sort here is for deterministic collection of schemas with generated
      # "refname".
      |> sort_by_key()
      |> Enum.map_reduce(ctx, fn {key, value}, ctx ->
        bin_key = ensure_binary_key(key)
        {value, ctx} = downpath(ctx, bin_key, &apply_caster(value, caster, &1))
        {{bin_key, value}, ctx}
      end)

    {Map.new(pairs), ctx}
  end

  defp apply_caster(data, {:map, _}, ctx) do
    raise NormalizeError,
      ctx: ctx,
      reason: raise(ArgumentError, "expected a map but got: #{inspect(data)}")
  end

  # with :or_ref we do not apply the cast if there is a reference
  defp apply_caster(data, {:or_ref, caster}, ctx) do
    case normalize_openapi_reference(data) do
      {:ok, refschema} -> {refschema, ctx}
      :error -> apply_caster(data, caster, ctx)
    end
  end

  defp apply_caster(data, module, ctx) when is_atom(module) do
    normalize!(data, module, ctx)
  end

  # checks if the given term is a reference provided by the users
  defp normalize_openapi_reference(term) when is_map(term) and not is_struct(term) do
    # $ref is allowed in schemas, and some entities only require a description,
    # while a Reference can also accept a description.
    #
    # So to determine if we are facing a reference we will check that the map only
    # contains $ref, summary and description keys and nothing else.
    with_normal_keys = Map.new(term, fn {k, v} -> {ensure_binary_key(k), v} end)

    if Map.has_key?(with_normal_keys, "$ref") and map_size(with_normal_keys) <= 3 and
         Enum.all?(Map.keys(with_normal_keys), &(&1 in ["$ref", "summary", "description"])) do
      {:ok, to_json_decoded(with_normal_keys)}
    else
      :error
    end
  end

  defp normalize_openapi_reference(%{__struct__: Reference} = ref) do
    normalize_openapi_reference(MapExt.from_struct_no_nils(ref))
  end

  defp normalize_openapi_reference(_) do
    :error
  end

  def to_json_decoded(data) do
    {data, _acc} = JSV.Normalizer.normalize(data, [], [])
    data
  end

  # Used when iterating over a map to ensure that generated schema refname is
  # made in a deterministic order.
  def sort_by_key(enum) do
    Enum.sort_by(enum, &elem(&1, 0))
  end

  # Normalizing schemas

  defp do_normalize_schema(schema, ctx) do
    # TODO raise if not valid schema (map or boolean) (null should not be
    # present at all)
    deep_normalize_schema(schema, ctx)
  end

  # Scalar values
  #
  # At the top level this will have the following behaviour:
  # * Booleans are valid schemas so we will store them.
  # * Other scalar values are not valid but we do not care here, we store them.
  #   They will be rejected on validation.
  #
  # When nested in a list or map, it's a sub schema value.

  defp deep_normalize_schema(scalar, ctx)
       when is_binary(scalar)
       when is_number(scalar)
       when is_boolean(scalar)
       when is_nil(scalar) do
    {scalar, ctx}
  end

  # Atom schemas
  #
  # When the atom is a module  that has already been normalized, we can just
  # reuse the reference name of the schema.
  defp deep_normalize_schema(module, ctx) when is_map_key(ctx.seen_schema_mods, module) do
    refname = Map.fetch!(ctx.seen_schema_mods, module)
    replacement = refname_to_schema(refname)
    {replacement, ctx}
  end

  # Atom schemas
  #
  # When the atom is a module we will call the .json_schema() function from it,
  # otherwise it's a sub schema value, we turn it into a string.
  defp deep_normalize_schema(atom, ctx) when is_atom(atom) do
    if Schema.schema_module?(atom) do
      normalize_module_schema(atom, ctx)
    else
      deep_normalize_schema(Atom.to_string(atom), ctx)
    end
  end

  defp deep_normalize_schema(struct, ctx) when is_struct(struct) do
    struct
    |> JSV.Normalizer.Normalize.normalize()
    |> deep_normalize_schema(ctx)
  end

  defp deep_normalize_schema(map, ctx) when is_map(map) do
    {pairs, ctx} =
      Enum.map_reduce(map, ctx, fn {k, v}, ctx ->
        {v, ctx} = deep_normalize_schema(v, ctx)
        {{ensure_binary_key(k), v}, ctx}
      end)

    {Map.new(pairs), ctx}
  end

  defp deep_normalize_schema(list, ctx) when is_list(list) do
    Enum.map_reduce(list, ctx, &deep_normalize_schema/2)
  end

  defp normalize_module_schema(module, ctx) do
    # * First derive a name from the schema title, and set it as seen
    #   in the context.
    # * Then recurse on the schema to also turn nested atoms in
    #   references before storing the normal schema in context.
    # * Then return a reference.
    schema = Schema.from_module(module)

    # Title and name are not the same.
    #
    # `title` is whatever title the schema has, or fallback to the module name.
    # We do not change the title given by users and when using the module name
    # we do not put it into the schema. We just use it to define a name.
    #
    # `refname` will be part of "#/components/schemas/<name>", it is generated
    # by us, starting from the title/module-name if available, or incrementing a
    # `_#{i}` suffix until available.
    title = schema_title(schema, module)
    refname = available_schema_refname(ctx.components_schemas, title)

    # Recursion with the module already seen to avoid denormalizing the same
    # module twice. This also avoids infinite loops with two or more mutual
    # recursive schemas.
    ctx = %{
      ctx
      | seen_schema_mods: Map.put(ctx.seen_schema_mods, module, refname),
        components_schemas: Map.put(ctx.components_schemas, refname, :__placeholder__)
    }

    {normal_schema, ctx} = deep_normalize_schema(schema, ctx)

    ctx = %{
      ctx
      | components_schemas:
          Map.update!(ctx.components_schemas, refname, fn :__placeholder__ ->
            normal_schema
          end)
    }

    replacement = refname_to_schema(refname)
    {replacement, ctx}
  end

  defp refname_to_schema(refname) do
    %{"$ref" => "#/components/schemas/#{refname}"}
  end

  defp schema_title(%{"title" => title}, _module) when is_binary(title) and title != "" do
    title
  end

  defp schema_title(%{title: title}, _module) when is_binary(title) and title != "" do
    title
  end

  defp schema_title(_schema, module) do
    inspect(module)
  end

  defp available_schema_refname(schemas, title) do
    if Map.has_key?(schemas, title) do
      available_schema_refname(schemas, title, 1)
    else
      title
    end
  end

  defp available_schema_refname(_schemas, title, n) when n > 1000 do
    # This should not happen but lets not iterate forever
    raise "could not generate a unique name for #{title}"
  end

  defp available_schema_refname(schemas, title, n) do
    name = "#{title}_#{Integer.to_string(n)}"

    if Map.has_key?(schemas, name) do
      available_schema_refname(schemas, title, n + 1)
    else
      name
    end
  end
end
