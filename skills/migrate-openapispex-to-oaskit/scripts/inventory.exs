# Read-only inventory of OpenApiSpex usage in a Phoenix project.
#
#     elixir inventory.exs --project path/to/app [--routes]
#
# Prints counts and the locations of the patterns that need a decision or a
# manual fix during the migration. Never writes anything. Scans lib/**/*.ex,
# test/support/**/*.ex, test/**/*.exs, mix.exs and config/*.exs. Labels say
# "(auto)" when rewrite_lib.exs or rewrite_tests.exs handles the case, and
# otherwise name the file and section of references/ to read.
#
# --routes also runs `mix run` in the project (the project must compile) to
# list controller actions mounted on several routes, and schema titles shared
# by several OpenApiSpex schema modules reachable from the operations of one
# router.

defmodule Inventory do
  @oas30_schema_keys ~w(title multipleOf maximum exclusiveMaximum minimum exclusiveMinimum
    maxLength minLength pattern maxItems minItems uniqueItems maxProperties minProperties
    required enum type allOf oneOf anyOf not items properties additionalProperties
    description format default nullable discriminator readOnly writeOnly xml externalDocs
    example deprecated x-struct x-validate extensions)a

  # Keywords that are almost never legit property names. `type` and `required`
  # are common property names so they are not listed.
  @schema_keywords ~w(properties items allOf oneOf anyOf nullable additionalProperties)a

  # JSV default formats + Oaskit.JsonSchema.Formats, as of oaskit 0.16 / jsv 0.25.
  # Newer versions may know more formats: check the changelogs.
  @known_formats ~w(date date-time duration email hostname ipv4 ipv6 iri iri-reference
    json-pointer regex relative-json-pointer time unknown uri uri-reference uri-template uuid
    base64url binary byte char commonmark html media-range password double-int double float
    int16 int32 int8 uint8 uint16 uint32 decimal decimal128 int64 uint64 sf-binary sf-boolean
    sf-decimal sf-integer sf-string sf-token)

  # OpenApiSpex modules that rewrite_lib.exs does not remove: data from them
  # stays OpenApiSpex data.
  @runtime_spex ~r/OpenApiSpex\.(?!Schema\b|Discriminator\b|ControllerSpecs\b|Plug\.|schema\(|TestAssertions\b)/

  def run(argv) do
    {opts, _} = OptionParser.parse!(argv, strict: [project: :string, routes: :boolean])
    project = Path.expand(opts[:project] || ".")
    Process.put(:project, project)
    :ets.new(:inv, [:named_table, :bag, :public])

    lib =
      Path.wildcard(Path.join(project, "lib/**/*.ex")) ++
        Path.wildcard(Path.join(project, "test/support/**/*.ex"))
    tests = Path.wildcard(Path.join(project, "test/**/*.exs"))

    Enum.each(lib, &scan_file(&1, :lib))
    Enum.each(tests, &scan_file(&1, :test))
    scan_project_files(project)

    print_report()

    if opts[:routes], do: print_routes(project)

    print_summary()
  end

  # -- recording --------------------------------------------------------------

  defp hit(kind, file, meta, detail \\ nil) do
    detail = if is_binary(detail), do: String.replace(detail, ~r/\s+/, " "), else: detail
    :ets.insert(:inv, {kind, {rel(file), meta[:line]}, detail})
  end

  defp count(kind), do: length(:ets.lookup(:inv, kind))

  defp rel(file), do: Path.relative_to(file, Process.get(:project))

  # -- scanning ---------------------------------------------------------------

  defp scan_file(file, scope) do
    src = File.read!(file)

    if String.contains?(src, "OpenApiSpex") or String.contains?(src, "operation") or
         String.contains?(src, "assert_schema") do
      case Code.string_to_quoted(src, columns: false) do
        {:ok, ast} -> scan_ast(ast, file, scope, src)
        {:error, _} -> hit(:parse_error, file, [])
      end
    end
  end

  defp scan_ast(ast, file, scope, src) do
    if scope == :lib and String.contains?(src, "OpenApiSpex.Plug.CastAndValidate") == false and
         Regex.match?(~r/^\s+operation[\s(]+:/m, src) and String.contains?(src, "ControllerSpecs") do
      hit(:controller_without_cast_and_validate, file, line: 1)
    end

    if String.contains?(src, "security:") and String.contains?(src, "ControllerSpecs") do
      hit(:controller_with_security, file, line: 1)
    end

    Process.put(:module_stack, [])
    Process.put(:def_stack, [])
    Process.put(:quote_depth, 0)
    Process.put(:mentions_spex, String.contains?(src, "OpenApiSpex"))
    Process.put(:still_spex, Regex.match?(@runtime_spex, src))
    Process.put(:imports_spex, Regex.match?(~r/^\s*import OpenApiSpex\s*$/m, src))

    Macro.traverse(
      ast,
      nil,
      fn node, acc ->
        push_module(node)
        push_def(node)
        push_quote(node)

        if not MapSet.member?(Process.get(:skip_nodes, MapSet.new()), node),
          do: visit(node, file, scope)

        {node, acc}
      end,
      fn node, acc ->
        pop_module(node)
        pop_def(node)
        pop_quote(node)
        {node, acc}
      end
    )
  end

  defp push_module({:defmodule, _, [{:__aliases__, _, parts}, _]}) do
    stack = Process.get(:module_stack)
    parent = List.first(stack, [])
    Process.put(:module_stack, [parent ++ parts | stack])
  end

  defp push_module(_), do: :ok

  defp pop_module({:defmodule, _, [{:__aliases__, _, _}, _]}),
    do: Process.put(:module_stack, tl(Process.get(:module_stack)))

  defp pop_module(_), do: :ok

  defp push_def({kind, _, [head | _]}) when kind in [:def, :defp] do
    Process.put(:def_stack, [def_name(head) | Process.get(:def_stack)])
  end

  defp push_def(_), do: :ok

  defp pop_def({kind, _, [_ | _]}) when kind in [:def, :defp],
    do: Process.put(:def_stack, tl(Process.get(:def_stack)))

  defp pop_def(_), do: :ok

  defp def_name({:when, _, [head | _]}), do: def_name(head)
  defp def_name({name, _, args}) when is_atom(name), do: {name, length(List.wrap(args))}
  defp def_name(_), do: {:"?", 0}

  defp push_quote({:quote, _, _}), do: Process.put(:quote_depth, Process.get(:quote_depth) + 1)
  defp push_quote(_), do: :ok
  defp pop_quote({:quote, _, _}), do: Process.put(:quote_depth, Process.get(:quote_depth) - 1)
  defp pop_quote(_), do: :ok

  defp skip_node(node), do: Process.put(:skip_nodes, MapSet.put(Process.get(:skip_nodes, MapSet.new()), node))

  # Every module of OpenApiSpex referenced, except the ones counted elsewhere.
  @covered_refs [[], [:Schema], [:Discriminator], [:ControllerSpecs], [:Plug, :CastAndValidate], [:Plug, :PutApiSpec]]

  defp visit_common(node, file) do
    case node do
      {{:., _, [{:__aliases__, _, [:OpenApiSpex]}, :{}]}, m, names} ->
        for {:__aliases__, _, parts} <- names,
            parts not in @covered_refs,
            do: hit({:spex_ref, "OpenApiSpex." <> Enum.join(parts, ".")}, file, m)

      {:__aliases__, m, [:OpenApiSpex | rest]} when rest not in @covered_refs ->
        hit({:spex_ref, Enum.join([:OpenApiSpex | rest], ".")}, file, m)

      {{:., m, [_, :open_api_spex]}, _, []} ->
        hit(:private_open_api_spex, file, m, "conn.private.open_api_spex")

      {:%{}, m, kv} when is_list(kv) ->
        if Keyword.keyword?(kv) and Keyword.has_key?(kv, :open_api_spex),
          do: hit(:private_open_api_spex, file, m, "%{open_api_spex: ...} pattern")

      # var.schema() on a variable: runtime schema inspection
      {{:., m, [{var, _, ctx}, :schema]}, _, []} when is_atom(var) and is_atom(ctx) ->
        hit(:runtime_schema_call, file, m, "#{var}.schema()")

      _ ->
        :ok
    end
  end

  defp current_module do
    case Process.get(:module_stack) do
      [parts | _] -> Enum.join(parts, ".")
      [] -> "?"
    end
  end

  defp visit(node, file, :test) do
    visit_common(node, file)

    case node do
      {name, m, args} when is_atom(name) and is_list(args) ->
        if Map.has_key?(Process.get(:wrappers, %{}), name),
          do: hit(:assert_schema_wrapper_call, file, m, to_string(name))

        visit_test_call(node, file)

      _ ->
        :ok
    end
  end

  defp visit(node, file, :lib) do
    visit_common(node, file)

    case node do
      {{:., m, [{:__aliases__, _, [:OpenApiSpex]}, :schema]}, _, [schema | opts]} ->
        visit_schema_module(schema, opts, file, m)

      # expr |> OpenApiSpex.schema(opts)
      {:|>, m, [schema, {{:., _, [{:__aliases__, _, [:OpenApiSpex]}, :schema]}, _, opts} = call]} ->
        skip_node(call)
        visit_schema_module(schema, opts, file, m)

      # schema(...) with `import OpenApiSpex`
      {:|>, m, [schema, {:schema, _, opts} = call]} when is_list(opts) ->
        if Process.get(:imports_spex) do
          skip_node(call)
          visit_schema_module(schema, opts, file, m)
        end

      {:schema, m, [schema | opts]} when length(opts) <= 1 ->
        if Process.get(:imports_spex), do: visit_schema_module(schema, opts, file, m)

      {:import, m, [{:__aliases__, _, [:OpenApiSpex]}]} ->
        hit(:import_openapispex, file, m)

      # A schema module written by hand: def schema, do: %Schema{...}
      {:def, m, [{:schema, _, ctx}, body]} when ctx in [nil, []] ->
        if Process.get(:mentions_spex) and schema_body?(body),
          do: hit(:handwritten_schema_module, file, m, current_module())

      {:=, m, [{:%, _, [{:__aliases__, _, path}, _]}, rhs]}
      when path in [[:Schema], [:OpenApiSpex, :Schema]] ->
        if Process.get(:still_spex) and not schema_call_rhs?(rhs),
          do: hit(:schema_struct_pattern, file, m, Macro.to_string(rhs) |> String.slice(0, 60))

      {:@, m, [{:behaviour, _, [{:__aliases__, _, parts}]}]}
      when parts in [[:OpenApiSpex, :OpenApi], [:OpenApi]] ->
        if Process.get(:mentions_spex), do: hit_spec_module(file, m, current_module())

      {:assert_schema, m, _} ->
        hit(:assert_schema_wrapper, file, m, wrapper_name())

      {{:., m, [{:__aliases__, _, [:OpenApiSpex, :TestAssertions]}, :assert_schema]}, _, _} ->
        hit(:assert_schema_wrapper, file, m, wrapper_name())

      {:%, m, [{:__aliases__, _, path}, {:%{}, _, kv}]}
      when path in [[:Schema], [:OpenApiSpex, :Schema]] ->
        hit(:schema_struct, file, m)
        visit_schema_map(kv, file, m)

      {{:., m, [{:__aliases__, _, [:OpenApiSpex]}, fun]}, _, _}
      when fun in [:cast_value, :cast, :cast_and_validate] ->
        hit(:runtime_cast, file, m, "OpenApiSpex.#{fun}")

      {{:., m, [{:__aliases__, _, [:OpenApiSpex, :Cast | _]}, fun]}, _, _} ->
        hit(:runtime_cast, file, m, "OpenApiSpex.Cast.#{fun}")

      # X.schema().field
      {{:., m, [{{:., _, [{:__aliases__, _, mod}, :schema]}, _, []}, field]}, _, []}
      when mod != [:OpenApiSpex] ->
        hit(:schema_field_access, file, m, "#{Enum.join(mod, ".")}.schema().#{field}")

      # %{X.schema() | ...}
      {:%{}, m, [{:|, _, [{{:., _, [{:__aliases__, _, mod}, :schema]}, _, []}, kv]}]} ->
        hit(:schema_update, file, m, "%{#{Enum.join(mod, ".")}.schema() | #{inspect_keys(kv)}}")

      # X.schema() |> Map.put(...)
      {:|>, m,
       [{{:., _, [{:__aliases__, _, mod}, :schema]}, _, []}, {{:., _, [{:__aliases__, _, [:Map]}, f]}, _, _}]} ->
        hit(:schema_update, file, m, "#{Enum.join(mod, ".")}.schema() |> Map.#{f}(...)")

      {:use, m, [{:__aliases__, _, [:OpenApiSpex, :ControllerSpecs]} | _]} ->
        hit(:controller_specs, file, m)

        if Process.get(:quote_depth) > 0,
          do: hit(:openapispex_in_quote, file, m, "use OpenApiSpex.ControllerSpecs in #{current_def()}")

      {:plug, m, [{:__aliases__, _, [:OpenApiSpex, :Plug, plug]} | rest]} ->
        visit_plug(plug, rest, file, m)

        if Process.get(:quote_depth) > 0,
          do: hit(:openapispex_in_quote, file, m, "plug OpenApiSpex.Plug.#{plug} in #{current_def()}")

      {:operation, m, [_action, spec]} when is_list(spec) ->
        visit_operation(spec, file, m)

      {:operation, m, [_action, false]} ->
        hit(:operation_false, file, m)

      {:resources, m, args} ->
        visit_resources(args, file, m)

      {:get, m, [_, {:__aliases__, _, [:OpenApiSpex, :Plug, plug]} | _]} ->
        hit(:spec_route, file, m, "OpenApiSpex.Plug.#{plug}")

      {{:., m, [{:__aliases__, _, [:Server]}, :from_endpoint]}, _, _} ->
        hit(:server_from_endpoint, file, m)

      {{:., m, [{:__aliases__, _, [:OpenApiSpex, :Server]}, :from_endpoint]}, _, _} ->
        hit(:server_from_endpoint, file, m)

      {{:., m, [{:__aliases__, _, [:OpenApiSpex]}, :resolve_schema_modules]}, _, _} ->
        hit_spec_module(file, m, current_module())

      # A schema map outside OpenApiSpex.schema/1 (built by a helper, merged
      # into another schema...), recognized by its nullable key.
      {:%{}, m, kv} = map when is_list(kv) ->
        if Keyword.keyword?(kv) and Keyword.has_key?(kv, :nullable) and
             not MapSet.member?(Process.get(:visited_maps, MapSet.new()), map),
           do: visit_schema_map(kv, file, m)

      _ ->
        :ok
    end
  end

  defp visit_test_call(node, file) do
    case node do
      {:assert_schema, m, _} -> hit(:assert_schema, file, m)
      {:assert_raw_schema, m, _} -> hit(:assert_raw_schema, file, m)
      {:assert_operation_response, m, _} -> hit(:assert_operation_response, file, m)
      {:import, m, [{:__aliases__, _, [:OpenApiSpex | _]} = mod | _]} ->
        skip_node(mod)
        hit(:test_import, file, m)
      _ -> :ok
    end
  end

  defp inspect_keys(kv) when is_list(kv), do: kv |> Keyword.keys() |> Enum.map_join(", ", &"#{&1}: ...")
  defp inspect_keys(_), do: "..."

  defp current_def do
    case Process.get(:def_stack) do
      [{name, arity} | _] -> "#{name}/#{arity}"
      [] -> "?"
    end
  end

  defp wrapper_name do
    case Process.get(:def_stack) do
      [{name, arity} | _] ->
        Process.put(:wrappers, Map.put(Process.get(:wrappers, %{}), name, arity))
        "#{current_module()}.#{name}/#{arity}"

      [] ->
        current_module()
    end
  end

  # One entry per spec module, whatever found it.
  defp hit_spec_module(file, m, mod) do
    if not Enum.any?(:ets.lookup(:inv, :spec_module), fn {_, _, d} -> d == mod end),
      do: hit(:spec_module, file, m, mod)
  end

  defp schema_struct?({:%, _, [{:__aliases__, _, path}, _]}), do: path in [[:Schema], [:OpenApiSpex, :Schema]]
  defp schema_struct?(_), do: false

  defp schema_call?({{:., _, [{:__aliases__, _, mod}, :schema]}, _, []}), do: mod != [:OpenApiSpex]
  defp schema_call?(_), do: false

  defp schema_call_rhs?({:=, _, [_, rhs]}), do: schema_call_rhs?(rhs)
  defp schema_call_rhs?(rhs), do: schema_call?(rhs)

  defp schema_body?(body) do
    {_, found} =
      Macro.prewalk(body, false, fn n, acc -> {n, acc or schema_struct?(n) or schema_call?(n)} end)

    found
  end

  defp visit_schema_module(schema, opts, file, m) do
    no_struct? =
      case opts do
        [] ->
          false

        [kv] when is_list(kv) ->
          if Keyword.keyword?(kv) and Keyword.keys(kv) -- [:struct?, :derive?] == [] do
            if Keyword.get(kv, :struct?) == false, do: hit(:schema_struct_false, file, m)
            Keyword.get(kv, :struct?) == false
          else
            hit(:schema_macro_opts, file, m, Macro.to_string(kv))
            false
          end

        [other | _] ->
          hit(:schema_macro_opts, file, m, Macro.to_string(other))
          false
      end

    case schema do
      {:%{}, _, kv} ->
        Process.put(:visited_maps, MapSet.put(Process.get(:visited_maps, MapSet.new()), schema))
        type = Keyword.get(kv, :type)

        kind =
          cond do
            type == :object and Keyword.has_key?(kv, :properties) -> :object
            type == :object and Keyword.has_key?(kv, :allOf) -> :object_allof
            type == :object -> :object_without_properties
            type == :array -> :array
            type == nil and Keyword.has_key?(kv, :allOf) -> :allof
            type == nil and Keyword.has_key?(kv, :oneOf) -> :oneof
            type == nil and Keyword.has_key?(kv, :anyOf) -> :anyof
            true -> :other
          end

        # struct?: false modules become plain JSV schema modules whatever their shape.
        if not no_struct? do
          hit({:schema_module, kind}, file, m, if(kind == :other, do: inspect(type)))

          if type == :object and Keyword.get(kv, :nullable) == true,
            do: hit(:nullable_object_module, file, m)
        end

        module = current_module()

        case Keyword.get(kv, :title) do
          nil ->
            hit(:untitled_schema_module, file, m, module)
            hit(:schema_title, file, m, {module |> String.split(".") |> List.last(), module, :implicit})

          t when is_binary(t) ->
            hit(:schema_title, file, m, {t, module, :explicit})

          _ ->
            :ok
        end

        visit_schema_map(kv, file, m)

      other ->
        hit(:schema_module_non_literal, file, m, Macro.to_string(other) |> String.slice(0, 60))
    end
  end

  defp visit_schema_map(kv, file, m) do
    if not Keyword.keyword?(kv), do: throw(:skip)

    nullable = Keyword.get(kv, :nullable)
    if nullable != nil, do: hit(:nullable, file, m)

    if nullable == true do
      cond do
        Keyword.has_key?(kv, :allOf) -> hit(:nullable_allof, file, m)
        not Keyword.has_key?(kv, :type) and not Keyword.has_key?(kv, :oneOf) and
            not Keyword.has_key?(kv, :anyOf) ->
          hit(:nullable_without_type, file, m)
        Keyword.has_key?(kv, :enum) -> hit(:nullable_enum, file, m)
        true -> :ok
      end
    end

    if Keyword.has_key?(kv, :example), do: hit(:example, file, m)

    case Keyword.get(kv, :format) do
      nil -> :ok
      f when is_atom(f) or is_binary(f) ->
        unless to_string(f) in @known_formats, do: hit(:unknown_format, file, m, inspect(f))
      _ -> :ok
    end

    case Keyword.get(kv, :items) do
      {{:., _, [{:__aliases__, _, mod}, :schema]}, _, []} ->
        hit(:module_schema_items, file, m, "items: #{Enum.join(mod, ".")}.schema()")

      {:__aliases__, _, mod} ->
        hit(:module_items, file, m, "items: #{Enum.join(mod, ".")}")

      _ ->
        :ok
    end

    unknown = Keyword.keys(kv) -- @oas30_schema_keys
    if unknown != [], do: hit(:unknown_schema_key, file, m, inspect(unknown))

    case Keyword.get(kv, :properties) do
      {:%{}, _, props} when is_list(props) ->
        keys = Enum.flat_map(props, fn {k, _} when is_atom(k) -> [k]; _ -> [] end)
        suspicious = Enum.filter(keys, &(&1 in @schema_keywords))

        for {_, {{:., _, [{:__aliases__, _, _}, :schema]}, pm, []}} <- props,
            do: hit(:module_schema_property, file, pm)

        if suspicious != [],
          do: hit(:schema_keyword_in_properties, file, m, inspect(suspicious))

        case Keyword.get(kv, :required) do
          req when is_list(req) ->
            missing = Enum.filter(req, &is_atom/1) -- keys
            if missing != [], do: hit(:required_not_in_properties, file, m, inspect(missing))

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  catch
    :skip -> :ok
  end

  defp visit_plug(:CastAndValidate, rest, file, m) do
    opts =
      case rest do
        [kv] when is_list(kv) -> kv
        _ -> []
      end

    hit(:cast_and_validate, file, m)

    if Keyword.get(opts, :replace_params, true) != false,
      do: hit(:cast_and_validate_replace_params, file, m)

    case Keyword.get(opts, :render_error) do
      nil -> :ok
      mod -> hit(:render_error, file, m, Macro.to_string(mod))
    end
  end

  defp visit_plug(:PutApiSpec, rest, file, m) do
    hit({:plug, :PutApiSpec}, file, m)

    with [kv] when is_list(kv) <- rest,
         {:__aliases__, _, parts} <- Keyword.get(kv, :module) do
      hit_spec_module(file, m, Enum.join(parts, "."))
    end
  end
  defp visit_plug(plug, _rest, file, m), do: hit(:other_openapispex_plug, file, m, "OpenApiSpex.Plug.#{plug}")

  defp visit_operation(spec, file, m) do
    hit(:operation, file, m)
    if not Keyword.has_key?(spec, :operation_id), do: hit(:operation_without_id, file, m)
    if Keyword.has_key?(spec, :security), do: hit(:operation_with_security, file, m)

    case Keyword.get(spec, :request_body) do
      nil ->
        :ok

      {:{}, _, [_, _, schema]} ->
        hit(:request_body_tuple3, file, m)
        maybe_array_body(schema, file, m)

      {:{}, _, [_, _, schema, _]} ->
        hit(:request_body_tuple4, file, m)
        maybe_array_body(schema, file, m)

      other ->
        hit(:request_body_other, file, m, Macro.to_string(other) |> String.slice(0, 60))
    end

    params =
      case Keyword.get(spec, :parameters) do
        {:%{}, _, kv} -> kv
        other -> other
      end

    case params do
      params when is_list(params) ->
        for {name, popts} <- params, is_list(popts), Keyword.keyword?(popts) do
          if not Keyword.has_key?(popts, :in), do: hit(:parameter_without_in, file, m, inspect(name))

          case Keyword.get(popts, :name) do
            nil -> :ok
            ^name -> :ok
            other -> hit(:parameter_name_option, file, m, "#{name}: [name: #{inspect(other)}]")
          end

          case Keyword.get(popts, :schema) do
            {:%, _, [_, {:%{}, _, skv}]} ->
              if is_list(skv) and Keyword.get(skv, :nullable) == true,
                do: hit(:parameter_nullable, file, m, inspect(name))

            _ ->
              :ok
          end
        end

      nil ->
        :ok

      other ->
        hit(:parameters_non_literal, file, m, Macro.to_string(other) |> String.slice(0, 60))
    end

    responses =
      case Keyword.get(spec, :responses) do
        {:%{}, _, kv} -> kv
        kv when is_list(kv) -> kv
        nil -> []
        other ->
          hit(:responses_non_literal, file, m, Macro.to_string(other) |> String.slice(0, 60))
          []
      end

    for {_code, resp} <- responses do
      case resp do
        {:{}, _, [_, ct, _]} when ct != "application/json" -> hit(:response_other_content_type, file, m, ct)
        {:{}, _, [_, _, _]} -> hit(:response_tuple3, file, m)
        b when is_binary(b) -> hit(:response_description_only, file, m)
        _ -> hit(:response_other, file, m)
      end
    end
  end

  defp maybe_array_body({:%, _, [_, {:%{}, _, kv}]}, file, m) do
    if Keyword.get(kv, :type) == :array, do: hit(:array_request_body, file, m)
  end

  defp maybe_array_body(_, _, _), do: :ok

  defp visit_resources(args, file, m) do
    opts =
      args
      |> Enum.reverse()
      |> Enum.find(fn a -> is_list(a) and Keyword.keyword?(a) and not Keyword.has_key?(a, :do) end)

    only =
      if is_list(opts) and Keyword.keyword?(opts), do: Keyword.get(opts, :only), else: nil

    except =
      if is_list(opts) and Keyword.keyword?(opts), do: Keyword.get(opts, :except), else: nil

    has_update =
      cond do
        is_list(only) -> :update in only
        is_list(except) -> :update not in except
        true -> true
      end

    if has_update, do: hit(:resources_with_update, file, m)
  end

  defp scan_project_files(project) do
    mix = Path.join(project, "mix.exs")

    if File.exists?(mix) do
      src = File.read!(mix)

      for t <- ["openapi.spec.json", "openapi.spec.yaml", "open_api_spex"],
          String.contains?(src, t),
          do: hit(:mix_exs, mix, [line: line_of(src, t)], t)
    end

    for f <- Path.wildcard(Path.join(project, "config/*.exs")),
        src = File.read!(f),
        String.contains?(src, "open_api_spex") or String.contains?(src, "OpenApiSpex"),
        do: hit(:config, f, line: line_of(src, if(String.contains?(src, "open_api_spex"), do: "open_api_spex", else: "OpenApiSpex")))
  end

  defp line_of(src, needle) do
    src |> String.split("\n") |> Enum.find_index(&String.contains?(&1, needle)) |> Kernel.||(0) |> Kernel.+(1)
  end

  # -- report -------------------------------------------------------------------

  # Labels: "(auto)" = rewritten by rewrite_lib.exs or rewrite_tests.exs,
  # otherwise the reference to read. All references are in references/.
  @sections [
    {"OpenApiSpex schema modules (OpenApiSpex.schema/1 calls)",
     [
       {{:schema_module, :object}, "type: :object with properties -> defschema (auto)"},
       {{:schema_module, :array}, "type: :array -> def json_schema (auto)"},
       {{:schema_module, :other}, "other top-level type, e.g. a string enum -> def json_schema (auto)"},
       {{:schema_module, :oneof}, "top-level oneOf -> def json_schema (auto)"},
       {{:schema_module, :anyof}, "top-level anyOf -> def json_schema (auto)"},
       {{:schema_module, :allof}, "top-level allOf -> by hand: schemas.md \"Top-level allOf\""},
       {{:schema_module, :object_allof},
        "type: :object with allOf -> by hand: schemas.md \"Top-level allOf\""},
       {{:schema_module, :object_without_properties},
        "type: :object without properties (OpenApiSpex returned the data unchanged) -> by hand: schemas.md \"Object schemas without properties\""},
       {:schema_module_non_literal, "argument is not a %{...} map literal -> by hand: schemas.md \"Mapping\""},
       {:schema_struct_false, "OpenApiSpex.schema/2 with struct?: false -> def json_schema (auto)"},
       {:schema_macro_opts, "OpenApiSpex.schema/2 with other options -> by hand: schemas.md \"Mapping\""},
       {:import_openapispex, "import OpenApiSpex (bare schema(...) calls, counted above) -> use JSV.Schema (auto)"},
       {:handwritten_schema_module,
        "def schema written by hand, returning a %OpenApiSpex.Schema{} -> def json_schema (auto)"},
       {:nullable_object_module,
        "type: :object + nullable: true -> wrap every reference with nullable(Module): schemas.md \"nullable\""},
       {:untitled_schema_module,
        "without title (OpenApiSpex used the last module segment, Oaskit uses the full module name) -> schemas.md \"Titles and components\""}
     ]},
    {"Schema definitions (OpenApiSpex.schema/1 maps and %OpenApiSpex.Schema{} structs)",
     [
       {:schema_struct, "%OpenApiSpex.Schema{} structs -> schema maps (auto)"},
       {:nullable, "nullable keys (auto, except below)"},
       {:nullable_enum, "nullable + enum -> nil added to enum (auto)"},
       {:nullable_allof, "nullable + allOf -> anyOf with %{type: :null} (auto)"},
       {:nullable_without_type, "nullable without type -> by hand: schemas.md \"nullable\""},
       {:example, "example keys -> examples: [...] (auto)"},
       {:unknown_format,
        "format unknown to JSV/Oaskit, raises when Oaskit builds the OpenAPI document -> schemas.md \"Formats\""},
       {:required_not_in_properties,
        "required key not in properties (defschema raises) -> schemas.md \"JSV struct modules (defschema)\""},
       {:schema_keyword_in_properties,
        "schema keyword used as a property name, likely a bug -> schemas.md \"Mistakes revealed by the stricter tooling\""},
       {:unknown_schema_key,
        "key that is not an OpenAPI 3.0 schema keyword, likely a bug -> schemas.md \"Mistakes revealed by the stricter tooling\""}
     ]},
    {"Code using OpenApiSpex schema modules (Module.schema(), var.schema(), OpenApiSpex casting)",
     [
       {:schema_field_access,
        "Module.schema().field -> Module.json_schema().field or Map.get(...) (auto, KeyError risk for other fields)"},
       {:schema_update,
        "modified copies of Module.schema() -> nullable(Module) (auto for nullable), others by hand: schemas.md \"Mapping\""},
       {:runtime_cast,
        "OpenApiSpex casting outside requests -> casting-outside-requests.md"},
       {:runtime_schema_call,
        "var.schema() on a variable (code reading schemas at runtime) -> casting-outside-requests.md \"Code that reads schemas at runtime\""},
       {:module_schema_items,
        "items: Module.schema() (an inline %OpenApiSpex.Schema{} struct, a module atom after the rewrite; matters for code reading schemas at runtime) -> casting-outside-requests.md \"Code that reads schemas at runtime\""},
       {:module_items,
        "items: Module (a module atom before and after the rewrite: the sites above become indistinguishable from these ones) -> casting-outside-requests.md \"Code that reads schemas at runtime\""},
       {:module_schema_property,
        "properties written Module.schema() (same change as above, not listed)"},
       {:schema_struct_pattern,
        "%OpenApiSpex.Schema{} = expr in a file using other OpenApiSpex modules at runtime (the data may come from OpenApiSpex, e.g. a decoded OpenAPI document) -> casting-outside-requests.md \"Third-party OpenAPI 3.0 documents\""},
       {:private_open_api_spex,
        "conn.private.open_api_spex (set by the OpenApiSpex plugs) -> controllers.md \"conn.private.open_api_spex\""}
     ]},
    {"Controllers",
     [
       {:controller_specs, "use OpenApiSpex.ControllerSpecs -> use Oaskit.Controller (auto)"},
       {:openapispex_in_quote,
        "OpenApiSpex used inside a quote (web module function such as api_controller/0): every controller using it is concerned (auto)"},
       {:cast_and_validate, "OpenApiSpex.Plug.CastAndValidate -> Oaskit.Plugs.ValidateRequest (auto)"},
       {:cast_and_validate_replace_params,
        "CastAndValidate with replace_params: true (default), actions read OpenApiSpex-cast params -> controllers.md \"Phoenix params vs cast values\""},
       {:render_error, "custom :render_error plug -> error handler: errors.md"},
       {:controller_without_cast_and_validate,
        "operations but no CastAndValidate -> controllers.md \"Controllers with operations but no validation plug\""},
       {:controller_with_security, "operations declaring security: -> controllers.md \"Security\""},
       {:operation, "operations"},
       {:operation_without_id,
        "operations without operation_id (default operationId differs) -> controllers.md \"Operation IDs\""},
       {:operation_false, "operation(:x, false) (unchanged; tests keep json_response/2)"},
       {:request_body_tuple3,
        "request_body {desc, content_type, schema}, optional in OpenApiSpex (auto, becomes required) -> controllers.md \"Request bodies: the shortcut makes them required\""},
       {:request_body_tuple4, "request_body {desc, content_type, schema, opts} (auto)"},
       {:request_body_other, "request_body other shapes -> by hand: controllers.md \"Mapping\""},
       {:array_request_body, "array request bodies -> controllers.md \"JSON array request bodies\""},
       {:response_tuple3, "responses {desc, content_type, schema} (auto)"},
       {:response_description_only, "responses given as a description string (auto)"},
       {:response_other_content_type, "responses with a non-JSON content type (auto)"},
       {:response_other, "other response shapes -> by hand: controllers.md \"Mapping\""},
       {:responses_non_literal,
        "responses built by a function call -> controllers.md \"Responses built by a function\""},
       {:parameters_non_literal,
        "parameters built by a function call (in:, name: and nullable not checked) -> controllers.md \"Parameters\""},
       {:parameter_without_in, "parameters without in: (OpenApiSpex defaulted to :query) -> in: :query (auto)"},
       {:parameter_name_option,
        "parameters with a name: option different from their key (Oaskit uses the key) -> key renamed (auto)"},
       {:parameter_nullable,
        "nullable parameter schemas (Oaskit does not cast strings for type unions) -> nullable dropped (auto)"}
     ]},
    {"Router, spec modules, project files (by hand: spec-and-router.md)",
     [
       {{:plug, :PutApiSpec}, "PutApiSpec plugs -> Oaskit.Plugs.SpecProvider"},
       {:other_openapispex_plug, "other OpenApiSpex plugs"},
       {:spec_route, "RenderSpec / SwaggerUI routes -> Oaskit.SpecController"},
       {:resources_with_update,
        "resources with :update (PUT and PATCH on one action) -> controllers.md \"One controller action, several routes\""},
       {:spec_module,
        "spec modules (@behaviour OpenApiSpex.OpenApi, resolve_schema_modules, PutApiSpec module:), commands at the end of this report"},
       {:server_from_endpoint,
        "OpenApiSpex.Server.from_endpoint -> Oaskit.Spec.Server.from_config (dump the old OpenAPI document with --start-app=true)"},
       {:mix_exs, "mix.exs lines mentioning open_api_spex / openapi.spec.*"},
       {:config, "config files mentioning OpenApiSpex"}
     ]},
    {"Tests (testing.md)",
     [
       {:test_import, "imports of OpenApiSpex test helpers (auto, removed)"},
       {:assert_schema, "OpenApiSpex.TestAssertions.assert_schema/3 (auto when paired with json_response)"},
       {:assert_raw_schema, "assert_raw_schema (by hand)"},
       {:assert_operation_response, "assert_operation_response (by hand)"},
       {:assert_schema_wrapper,
        "assert_schema inside a helper function (test/support) -> testing.md \"Helpers wrapping assert_schema\""},
       {:assert_schema_wrapper_call, "calls of those helpers in tests (auto with rewrite_tests.exs --wrapper NAME)"}
     ]}
  ]

  @grouped [:render_error, :schema_field_access, :assert_schema_wrapper_call]

  defp print_report do
    for {title, items} <- @sections do
      IO.puts("\n## #{title}\n")

      for {kind, label} <- items, (n = count(kind)) > 0 do
        IO.puts("- #{n} #{label}")

        cond do
          kind in @grouped ->
            :ets.lookup(:inv, kind)
            |> Enum.frequencies_by(fn {_, _, d} -> group_key(kind, d) end)
            |> Enum.sort_by(fn {_, n} -> -n end)
            |> Enum.each(fn {d, n} -> IO.puts("    #{n} x #{d}") end)

          list?(kind) ->
          :ets.lookup(:inv, kind)
          |> Enum.sort()
          |> Enum.each(fn {_, {f, l}, d} -> IO.puts("    #{f}:#{l}#{if d, do: "  #{d}"}") end)

          true ->
            :ok
        end
      end
    end

    titles = :ets.lookup(:inv, :schema_title) |> Enum.group_by(fn {_, _, {t, _, _}} -> t end)

    dups = titles |> Enum.filter(fn {_, rows} -> length(rows) > 1 end) |> Enum.sort()

    if dups != [] do
      IO.puts("""

      ## Schema titles shared by several OpenApiSpex schema modules, whole project

      Untitled modules are counted with their last module segment. Only titles
      shared inside one OpenAPI document matter (see the per-router list printed
      by --routes) -> schemas.md "Titles and components"
      """)

      for {t, rows} <- dups do
        IO.puts("- #{t}:")

        for {_, {f, l}, {_, mod, kind}} <- Enum.sort(rows),
            do: IO.puts("    #{f}:#{l}  #{mod}#{if kind == :implicit, do: " (untitled)"}")
      end
    end

    refs =
      :ets.tab2list(:inv)
      |> Enum.flat_map(fn
        {{:spex_ref, mod}, loc, _} -> [{mod, loc}]
        _ -> []
      end)
      |> Enum.group_by(fn {mod, _} -> mod end, fn {_, loc} -> loc end)
      |> Enum.sort()

    if refs != [] do
      IO.puts("""

      ## Other OpenApiSpex modules referenced (lib and tests)

      Every OpenApiSpex module written in the code, except Schema, Discriminator,
      ControllerSpecs, CastAndValidate and PutApiSpec. Some are counted above
      too. Each one must be gone at the end: check that a section of the skill
      covers it.
      """)

      for {mod, locs} <- refs do
        IO.puts("- #{length(locs)} #{mod}")
        for {f, l} <- Enum.sort(locs), do: IO.puts("    #{f}:#{l}")
      end
    end

    if count(:parse_error) > 0 do
      IO.puts("\n## Files that could not be parsed\n")
      for {_, {f, _}, _} <- :ets.lookup(:inv, :parse_error), do: IO.puts("- #{f}")
    end
  end

  @not_listed [:schema_struct, :nullable, :example, :operation, :cast_and_validate, :controller_specs,
               :response_tuple3, :response_description_only, :request_body_tuple3,
               :request_body_tuple4, :assert_schema, {:schema_module, :object}, :schema_title,
               :module_schema_property, :test_import]

  defp list?(kind), do: kind not in @not_listed

  # Printed last so that it survives a truncated output. Kinds not printed were
  # not found.
  defp print_summary do
    IO.puts("\n## Summary: cases handled by hand (kinds not listed: none found)\n")

    for {_, items} <- @sections,
        {kind, label} <- items,
        not (String.contains?(label, "(auto") and not String.contains?(label, "by hand") and
               not String.contains?(label, ".md")),
        kind not in [:operation, :spec_module],
        (n = count(kind)) > 0 do
      IO.puts("- #{n} #{label |> String.split(" -> ") |> hd()}")
    end

    specs = :ets.lookup(:inv, :spec_module) |> Enum.map(fn {_, _, mod} -> mod end) |> Enum.sort()

    if specs != [] do
      start_app = count(:server_from_endpoint) > 0
      short = Enum.map(specs, &List.last(String.split(&1, ".")))
      dump_name = if Enum.uniq(short) == short, do: &List.last(String.split(&1, ".")), else: & &1
      list = Enum.join(specs, ", ")

      IO.puts("""

      ## Spec modules and commands

      #{Enum.map_join(specs, "\n", &"- #{&1}")}

      Phase 0, old OpenAPI documents ($WORK: a directory outside the project):

      #{Enum.map_join(specs, "\n", &"    mix openapi.spec.json --spec #{&1} --start-app=#{start_app} --pretty=true $WORK/old_#{dump_name.(&1)}.json")}

      Phase 7 gate (after the migration of the spec modules):

          mix run --no-start -e 'for m <- [#{list}], do: Oaskit.build_spec!(m, cache: false, responses: true)'

      Phase 9, new OpenAPI documents:

      #{Enum.map_join(specs, "\n", &"    mix openapi.dump #{&1} -o $WORK/new_#{dump_name.(&1)}.json")}
      """)
    end
  end


  defp group_key(:schema_field_access, d), do: "X.schema()." <> (d |> String.split(".") |> List.last())
  defp group_key(_, d), do: d

  # -- routes -------------------------------------------------------------------

  defp print_routes(project) do
    code = ~S"""
    defmodule InventoryWalk do
      # Collects %{key => title} for the schemas that OpenApiSpex turns into
      # components: schema modules, and inline %OpenApiSpex.Schema{} structs
      # with a title (`Module.schema()` written inline carries its module in
      # "x-struct"). Struct patterns are avoided so this compiles without
      # OpenApiSpex.
      def schema(%{__struct__: OpenApiSpex.Schema} = s, acc) do
        title = Map.get(s, :title)
        key = Map.get(s, :"x-struct") || (title && {:inline, title})

        if key != nil and Map.has_key?(acc, key) do
          acc
        else
          acc = if key, do: Map.put(acc, key, title || key |> Module.split() |> List.last()), else: acc
          additional = Map.get(s, :additionalProperties)

          subs =
            List.wrap(Map.get(s, :items)) ++
              Map.values(Map.get(s, :properties) || %{}) ++
              (Map.get(s, :allOf) || []) ++
              (Map.get(s, :oneOf) || []) ++
              (Map.get(s, :anyOf) || []) ++
              List.wrap(Map.get(s, :not)) ++
              if(is_boolean(additional), do: [], else: List.wrap(additional))

          Enum.reduce(subs, acc, &schema/2)
        end
      end

      def schema(mod, acc) when is_atom(mod) and mod not in [nil, true, false] do
        if not Map.has_key?(acc, mod) and Code.ensure_loaded?(mod) and function_exported?(mod, :schema, 0) do
          s = mod.schema()
          schema(Map.put(s, :"x-struct", Map.get(s, :"x-struct") || mod), acc)
        else
          acc
        end
      end

      def schema(_, acc), do: acc

      def operation(nil, acc), do: acc

      def operation(op, acc) do
        params = Enum.flat_map(Map.get(op, :parameters) || [], &([Map.get(&1, :schema)] ++ content(&1)))
        body = content(Map.get(op, :requestBody))
        responses = (Map.get(op, :responses) || %{}) |> Map.values() |> Enum.flat_map(&content/1)
        Enum.reduce(params ++ body ++ responses, acc, &schema/2)
      end

      defp content(%{content: content}) when is_map(content),
        do: content |> Map.values() |> Enum.map(&Map.get(&1, :schema))

      defp content(_), do: []
    end

    app = Mix.Project.config()[:app]
    Application.load(app)
    {:ok, mods} = :application.get_key(app, :modules)
    walk? = Code.ensure_loaded?(OpenApiSpex.Schema)

    for mod <- mods, Code.ensure_loaded?(mod), function_exported?(mod, :__routes__, 0) do
      routes =
        Enum.filter(
          mod.__routes__(),
          &(is_atom(&1.plug_opts) and Code.ensure_loaded?(&1.plug) and
              function_exported?(&1.plug, :open_api_operation, 1))
        )

      routes
      |> Enum.group_by(&{&1.plug, &1.plug_opts})
      |> Enum.filter(fn {_, routes} -> length(routes) > 1 end)
      |> Enum.each(fn {{ctrl, action}, routes} ->
        paths = Enum.map_join(routes, ", ", &"#{&1.verb |> to_string() |> String.upcase()} #{&1.path}")
        IO.puts("INVENTORY_ROUTE #{inspect(mod)}: #{inspect(ctrl)}.#{action} -> #{paths}")
      end)

      if walk? do
        routes
        |> Enum.uniq_by(&{&1.plug, &1.plug_opts})
        |> Enum.reduce(%{}, fn r, acc ->
          InventoryWalk.operation(r.plug.open_api_operation(r.plug_opts), acc)
        end)
        |> Enum.group_by(fn {_, title} -> title end, fn
          {{:inline, _}, _} -> "an inline schema without x-struct"
          {m, _} -> inspect(m)
        end)
        |> Enum.filter(fn {_, ms} -> length(ms) > 1 end)
        |> Enum.sort()
        |> Enum.each(fn {title, ms} ->
          IO.puts("INVENTORY_TITLE #{inspect(mod)}: #{title} -> #{ms |> Enum.sort() |> Enum.join(", ")}")
        end)
      end
    end
    """

    {out, status} = System.cmd("mix", ["run", "--no-start", "-e", code], cd: project, stderr_to_stdout: true)
    lines = String.split(out, "\n")

    IO.puts("\n## Controller actions on several routes (duplicate operation ids in Oaskit)\n")
    print_prefixed(lines, status, out, "INVENTORY_ROUTE ")

    IO.puts("""

    ## Schema titles shared by several schema modules of one router

    Same OpenAPI document (when the spec module uses that router): OpenApiSpex
    kept one module under that component name, Oaskit suffixes one of them -> schemas.md
    "Titles and components"
    """)

    print_prefixed(lines, status, out, "INVENTORY_TITLE ")
  end

  defp print_prefixed(lines, 0, _out, prefix) do
    lines = Enum.filter(lines, &String.starts_with?(&1, prefix))
    if lines == [], do: IO.puts("- none")
    Enum.each(lines, &IO.puts("- " <> String.trim_leading(&1, prefix)))
  end

  defp print_prefixed(_lines, _status, out, _prefix),
    do: IO.puts("- could not run mix in the project:\n" <> out)
end

Inventory.run(System.argv())
