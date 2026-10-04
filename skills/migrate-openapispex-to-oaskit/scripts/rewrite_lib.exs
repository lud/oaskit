# Syntax rewrites of OpenApiSpex schema modules, %OpenApiSpex.Schema{}
# structs, and controller operations and validation plugs. Spec modules and
# routers are not touched.
#
#     elixir rewrite_lib.exs --project path/to/app [--error-handler MyAppWeb.ApiErrorHandler] [--titles] [--write] [paths...]
#
# --error-handler MODULE  module written in
#                         `plug Oaskit.Plugs.ValidateRequest, error_handler: MODULE`.
#                         Without it, the plug gets no :error_handler option
#                         and Oaskit.ErrorHandler.Default is used.
# --titles                add `title: "LastModuleSegment"` to OpenApiSpex schema
#                         modules without title, to keep their component names.
# --write                 apply the changes (dry run otherwise).
# paths                   files or directories relative to --project
#                         (default: lib).
#
# Needs deps/ fetched: the formatter options are read from .formatter.exs and
# deps/<dep>/.formatter.exs of each import_deps entry. See
# references/schemas.md and references/controllers.md for what each rule does
# and what the REPORT lines mean.

Mix.install([{:sourceror, "~> 1.7"}])
Code.require_file("common.exs", __DIR__)
alias Migration.Common, as: C

{opts, project, files} =
  C.parse_args!(System.argv(), [error_handler: :string, titles: :boolean], ["lib"])

fmt_opts = C.formatter_opts!(project)

# OpenApiSpex schema modules without a `properties` key (objects without
# properties, top-level allOf): `X.schema().properties` was nil for them.
defmodule Propless do
  def collect(files) do
    for file <- files,
        src = File.read!(file),
        String.contains?(src, "OpenApiSpex.schema("),
        {:ok, ast} = Code.string_to_quoted(src),
        mod <- in_ast(ast),
        uniq: true,
        do: mod
  end

  defp in_ast(ast) do
    {_, {_, found}} =
      Macro.traverse(
        ast,
        {[], []},
        fn
          {:defmodule, _, [{:__aliases__, _, parts}, _]} = node, {stack, found} ->
            {node, {[List.first(stack, []) ++ parts | stack], found}}

          {{:., _, [{:__aliases__, _, [:OpenApiSpex]}, :schema]}, _, [{:%{}, _, kv} | _]} = node,
          {[mod | _] = stack, found} ->
            if Keyword.keyword?(kv) and not Keyword.has_key?(kv, :properties) and
                 (Keyword.get(kv, :type) == :object or Keyword.has_key?(kv, :allOf)),
               do: {node, {stack, [mod | found]}},
               else: {node, {stack, found}}

          node, acc ->
            {node, acc}
        end,
        fn
          {:defmodule, _, [{:__aliases__, _, _}, _]} = node, {[_ | stack], found} -> {node, {stack, found}}
          node, acc -> {node, acc}
        end
      )

    found
  end
end

propless = Propless.collect(files)

defmodule Rewrite do
  import Migration.Common

  @doc_keys [:title, :description, :examples, :default, :deprecated, :readOnly, :writeOnly]

  # OpenApiSpex modules that this script does not remove: data from them stays
  # OpenApiSpex data.
  @runtime_spex ~r/OpenApiSpex\.(?!Schema\b|Discriminator\b|ControllerSpecs\b|Plug\.|schema\(|TestAssertions\b)/

  def transform(src, opts, propless) do
    # Controllers whose OpenApiSpex setup lives in the web module mention no
    # OpenApiSpex module, only operations.
    if String.contains?(src, "OpenApiSpex") or Regex.match?(~r/^\s*operation[\s(]+:/m, src) do
      Process.put(:opts, opts)
      Process.put(:propless, propless)
      imports_spex = Regex.match?(~r/^\s*import OpenApiSpex\s*$/m, src)
      Process.put(:imports_spex, imports_spex)
      Process.put(:has_require, String.contains?(src, "require OpenApiSpex") or imports_spex)
      Process.put(:still_spex, Regex.match?(@runtime_spex, src))

      Process.put(
        :needs_jsv,
        Regex.match?(~r/OpenApiSpex\.schema\b|nullable: true|:nullable, true/, src) or
          (imports_spex and Regex.match?(~r/\bschema\(/, src))
      )

      src
      |> Sourceror.parse_string!()
      |> then(&if(opts[:titles], do: add_titles(&1), else: &1))
      |> Macro.prewalk(&pre/1)
      |> Macro.postwalk(&post/1)
      |> move_file_level_use()
    else
      :skip
    end
  end

  defp schema_call?({{:., _, [{:__aliases__, _, aliases}, :schema]}, _, []}),
    do: aliases != [:OpenApiSpex]

  defp schema_call?(_), do: false

  defp alias_of({{:., _, [a, :schema]}, _, []}), do: a

  defp json_schema_call({{:., m, [a, :schema]}, m2, []}), do: {{:., m, [a, :json_schema]}, m2, []}

  defp spex_schema_fun?({{:., _, [{:__aliases__, _, [:OpenApiSpex]}, :schema]}, _, args}) when is_list(args),
    do: true

  defp spex_schema_fun?({:schema, _, args}) when is_list(args), do: Process.get(:imports_spex) == true
  defp spex_schema_fun?(_), do: false

  defp schema_struct?({:%, _, [{:__aliases__, _, path}, _]}), do: path in [[:Schema], [:OpenApiSpex, :Schema]]
  defp schema_struct?(_), do: false

  defp innermost_rhs({:=, _, [_, rhs]}), do: innermost_rhs(rhs)
  defp innermost_rhs(rhs), do: rhs

  # -- titles ------------------------------------------------------------------

  # OpenApiSpex named untitled schema modules after their last module segment.
  defp add_titles(ast) do
    {ast, _} =
      Macro.traverse(
        ast,
        [],
        fn
          {:defmodule, _, [{:__aliases__, _, parts}, _]} = node, stack ->
            {node, [List.last(parts) | stack]}

          {:defmodule, _, _} = node, stack ->
            {node, [nil | stack]}

          {:|>, m, [map, call]} = node, [mod | _] = stack ->
            if spex_schema_fun?(call), do: {{:|>, m, [put_title(map, mod), call]}, stack}, else: {node, stack}

          {fun, m, [map | rest]} = node, [mod | _] = stack when is_list(m) ->
            if spex_schema_fun?(node), do: {{fun, m, [put_title(map, mod) | rest]}, stack}, else: {node, stack}

          node, stack ->
            {node, stack}
        end,
        fn
          {:defmodule, _, _} = node, [_ | stack] -> {node, stack}
          node, stack -> {node, stack}
        end
      )

    ast
  end

  defp put_title({:%{}, mm, kv} = map, mod) when is_atom(mod) and mod != nil and is_list(kv) do
    if Enum.all?(kv, &(kw_key(&1) != nil)) and get_kv(kv, :title) == nil do
      info(mm, "title: \"#{mod}\" added (the component name OpenApiSpex gave this untitled schema module)")
      {:%{}, mm, [{key(:title), lit(to_string(mod))} | kv]}
    else
      map
    end
  end

  defp put_title(map, _), do: map

  # -- use JSV.Schema ----------------------------------------------------------

  # OpenApiSpex.schema/1 calls left as is are rewritten by hand, usually with
  # defschema.
  defp needs_jsv_schema?(ast) do
    contains?(ast, fn node ->
      match?({f, _, args} when f in [:defschema, :nullable] and is_list(args), node) or spex_schema_fun?(node)
    end)
  end

  defp jsv_use?({:use, m, [{:__aliases__, _, [:JSV, :Schema]}]}) when is_list(m), do: m[:jsv_marker] == true
  defp jsv_use?(_), do: false

  # A `require OpenApiSpex` written before `defmodule` became a file-level
  # `use JSV.Schema`: move it into the top-level modules that need it.
  defp move_file_level_use({:__block__, m, stmts} = ast) when is_list(stmts) do
    if Enum.any?(stmts, &jsv_use?/1) do
      {kept, pending} =
        Enum.reduce(stmts, {[], []}, fn stmt, {acc, pending} ->
          if jsv_use?(stmt),
            do: {acc, pending ++ leading_comments(stmt)},
            else: {[add_leading_comments(inject_use(stmt), pending) | acc], []}
        end)

      for %{text: text, line: line} <- pending,
          do: info(line, "comment removed with the statement below it: #{text}")

      {:__block__, m, Enum.reverse(kept)}
    else
      ast
    end
  end

  defp move_file_level_use(ast), do: ast

  defp inject_use({:defmodule, m, [name, [{do_key, body}]]} = node) do
    if needs_jsv_schema?(body) do
      use = {:use, [], [{:__aliases__, [], [:JSV, :Schema]}]}

      body =
        case body do
          {:__block__, bm, stmts} when is_list(stmts) ->
            {head, rest} = Enum.split_while(stmts, &module_header?/1)
            {:__block__, bm, head ++ [use | rest]}

          other ->
            {:__block__, [], [use, other]}
        end

      {:defmodule, m, [name, [{do_key, body}]]}
    else
      node
    end
  end

  defp inject_use(stmt), do: stmt

  defp module_header?({:@, _, [{attr, _, _}]}), do: attr in [:moduledoc, :shortdoc, :behaviour]
  defp module_header?({:use, _, _}), do: true
  defp module_header?(_), do: false

  defp alias_like?({kind, _, _}), do: kind in [:alias, :import, :require]
  defp alias_like?(_), do: false

  # use before alias, import and require (the order of credo's StrictModuleLayout).
  defp move_use_up(stmts) do
    case Enum.split_while(stmts, &(not alias_like?(&1))) do
      {_, []} ->
        stmts

      {before, rest} ->
        case Enum.split_with(rest, &jsv_use?/1) do
          {[], _} -> stmts
          {uses, rest} -> before ++ uses ++ rest
        end
    end
  end

  defp contains?(ast, pred) do
    {_, found} = Macro.prewalk(ast, false, fn n, acc -> {n, acc or pred.(n)} end)
    found
  end

  defp map_get_call(map_expr, k, default) do
    {{:., [], [{:__aliases__, [], [:Map]}, :get]}, [], [map_expr, lit(k), default]}
  end

  # -- prewalk: rewrites that need the parent node ---------------------------

  # X.schema().example -> hd(Map.get(X.json_schema(), :examples, [nil]))
  # X.schema().required -> Map.get(X.json_schema(), :required, [])
  # X.schema().properties -> X.json_schema().properties
  def pre({{:., m, [inner, field]}, m2, []} = node) when is_atom(field) do
    if schema_call?(inner) do
      js = json_schema_call(inner)

      case field do
        :example -> {:hd, [], [map_get_call(js, :examples, list([lit(nil)]))]}
        :required -> map_get_call(js, :required, list([]))
        :properties ->
          report_propless(m, alias_of(inner))
          {{:., m, [js, :properties]}, m2, []}

        other ->
          mod = alias_name(alias_of(inner))

          report(m, "#{mod}.schema().#{other} rewritten to #{mod}.json_schema().#{other}: raises KeyError " <>
            "if that schema map has no :#{other} key, use Map.get (references/schemas.md, \"Mapping\")")

          {{:., m, [js, other]}, m2, []}
      end
    else
      node
    end
  end

  # %{X.schema() | nullable: true} / %Schema{X.schema() | nullable: true} -> nullable(X)
  def pre({:%{}, m, [{:|, _, [inner, [pair]]}]} = node) do
    if kw_key(pair) == :nullable and unwrap(elem(pair, 1)) == true do
      {:nullable, m, [nullable_arg(inner)]}
    else
      node
    end
  end

  # expr |> Map.put(:nullable, true|false)
  def pre({:|>, m, [inner, {{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, [k, v]}]} = node),
    do: map_put_nullable(node, m, inner, k, v)

  # Map.put(expr, :nullable, true|false)
  def pre({{:., _, [{:__aliases__, _, [:Map]}, :put]}, m, [inner, k, v]} = node),
    do: map_put_nullable(node, m, inner, k, v)

  # expr |> OpenApiSpex.schema(opts) -> OpenApiSpex.schema(expr, opts), handled in post
  def pre({:|>, _, [arg, {fun, m, args} = call]} = node) when is_list(args) do
    if spex_schema_fun?(call), do: {fun, Keyword.put(m, :from_pipe, true), [arg | args]}, else: node
  end

  # var = X.schema() -> var = X.json_schema() (the value is used as a map)
  def pre({:=, m, [lhs, rhs]}) do
    if schema_struct?(lhs) and Process.get(:still_spex) and not schema_call?(innermost_rhs(rhs)) do
      report(m, "`%OpenApiSpex.Schema{} = ...` pattern rewritten to `%{} = ...` in a file that still uses other " <>
        "OpenApiSpex modules at runtime: if the matched data comes from OpenApiSpex (a decoded OpenAPI document, " <>
        "OpenApiSpex casting), migrate that code by hand (references/casting-outside-requests.md, " <>
        "\"Third-party OpenAPI 3.0 documents\")")
    end

    if schema_call?(rhs), do: {:=, m, [lhs, json_schema_call(rhs)]}, else: {:=, m, [lhs, rhs]}
  end

  # def schema, do: %Schema{...} written by hand -> def json_schema
  def pre({:def, m, [{:schema, hm, ctx}, body]} = node) when ctx in [nil, []] do
    if contains?(body, &(schema_struct?(&1) or schema_call?(&1))) do
      info(m, "def schema/0 returning an OpenApiSpex schema renamed to def json_schema/0 (a plain JSV schema module)")
      {:def, m, [{:json_schema, hm, ctx}, body]}
    else
      node
    end
  end

  # Parameters of operations, before their schemas are converted.
  def pre({:operation, m, [action, spec]}) when is_list(spec) do
    spec =
      Enum.map(spec, fn pair ->
        case {kw_key(pair), pair} do
          {:parameters, {k, {:%{}, mm, params}}} ->
            {k, {:%{}, mm, Enum.map(params, &convert_parameter(&1, m))}}

          {:parameters, {k, v}} ->
            case keyword_pairs(v) do
              nil ->
                report(m, "operation parameters built by a function call: in its arguments, keys renamed " <>
                  "after name:. Check that function by hand: Oaskit names parameters after their key " <>
                  "(a name: different from the key is ignored) (references/controllers.md, \"Parameters\")")

                {k, v |> drop_nullable_deep(m) |> rename_parameters_deep(m)}

              params ->
                {k, relist(v, Enum.map(params, &convert_parameter(&1, m)))}
            end

          _ ->
            pair
        end
      end)

    {:operation, m, [action, spec]}
  end

  def pre(list) when is_list(list) do
    if list != [] and parameter_opts?(list) do
      {_, schema} = get_kv(list, :schema)
      drop_parameter_nullable(list, if(is_tuple(schema), do: elem(schema, 1), else: []))
    else
      list
    end
  end

  def pre(node), do: node

  defp convert_parameter({k, v} = param, m) do
    case keyword_pairs(v) do
      nil ->
        param

      opts ->
        name = kw_key(param)

        opts =
          if get_kv(opts, :in) do
            opts
          else
            info(m, "parameter without in: given in: :query (OpenApiSpex's default, required by Oaskit)")
            opts ++ [{key(:in), lit(:query)}]
          end

        {k, opts} = rename_parameter(k, name, opts, m)
        opts = drop_parameter_nullable(opts, m)

        if {k, opts} == {elem(param, 0), keyword_pairs(v)}, do: param, else: {k, relist(v, opts)}
    end
  end

  defp convert_parameter(other, _m), do: other

  defp rename_parameter(k, name, opts, m) do
    case get_kv(opts, :name) do
      nil ->
        {k, opts}

      {_, nv} ->
        case unwrap(nv) do
          ^name ->
            {k, drop_kv(opts, :name)}

          new when is_atom(new) and new != nil ->
            info(m, "parameter #{name}: [name: #{inspect(new)}] renamed to #{new} (Oaskit names parameters " <>
              "after their key and ignores name:)")

            {key(new), drop_kv(opts, :name)}

          _ ->
            {k, opts}
        end
    end
  end

  defp drop_parameter_nullable(opts, m) do
    Enum.map(opts, fn
      {sk, {:%, sm, [a, {:%{}, mm, kv}]}} = pair ->
        if kw_key(pair) == :schema and drop_nullable?(kv, m),
          do: {sk, {:%, sm, [a, {:%{}, mm, drop_kv(kv, :nullable)}]}},
          else: pair

      {sk, {:%{}, mm, kv}} = pair ->
        if kw_key(pair) == :schema and drop_nullable?(kv, m),
          do: {sk, {:%{}, mm, drop_kv(kv, :nullable)}},
          else: pair

      pair ->
        pair
    end)
  end

  # Keyword arguments of a parameters helper: `id: [name: :run_id, ...]`.
  defp rename_parameters_deep(ast, m) do
    Macro.prewalk(ast, fn
      list when is_list(list) ->
        Enum.map(list, fn
          {k, v} = param ->
            name = kw_key(param)
            opts = keyword_pairs(v)

            if name && opts && Enum.all?(opts, &kw_key/1) do
              case rename_parameter(k, name, opts, m) do
                {^k, ^opts} -> param
                {k, opts} -> {k, relist(v, opts)}
              end
            else
              param
            end

          other ->
            other
        end)

      node ->
        node
    end)
  end

  @parameter_locations [:query, :path, :header, :cookie]

  # A keyword list with in: and schema: is a parameter, also when a project
  # function builds it.
  defp parameter_opts?(list) do
    Enum.all?(list, &kw_key/1) and get_kv(list, :schema) != nil and
      case get_kv(list, :in) do
        {_, v} -> unwrap(v) in @parameter_locations
        nil -> false
      end
  end

  defp drop_nullable_deep(ast, m) do
    Macro.prewalk(ast, fn
      {:%, sm, [a, {:%{}, mm, kv}]} = node ->
        if schema_struct?(node) and is_list(kv) and drop_nullable?(kv, m),
          do: {:%, sm, [a, {:%{}, mm, drop_kv(kv, :nullable)}]},
          else: node

      node ->
        node
    end)
  end

  defp relist({:__block__, bm, [_]}, items), do: {:__block__, bm, [items]}
  defp relist(_, items), do: items

  defp drop_nullable?(kv, m) do
    case get_kv(kv, :nullable) do
      nil ->
        false

      _ ->
        info(m, "nullable removed from a parameter schema: a path, query or header value is never null")

        true
    end
  end

  defp map_put_nullable(node, m, inner, k, v) do
    cond do
      unwrap(k) == :nullable and unwrap(v) == true ->
        if not Process.get(:has_require) do
          report(m, "nullable/1 introduced in a module without `require OpenApiSpex`: add " <>
            "`import JSV.Schema.Helpers, only: [nullable: 1]` (or `use JSV.Schema`)")
        end

        {:nullable, m, [nullable_arg(inner)]}

      unwrap(k) == :nullable and unwrap(v) == false ->
        nullable_arg(inner)

      true ->
        node
    end
  end

  defp nullable_arg(inner), do: if(schema_call?(inner), do: alias_of(inner), else: inner)

  defp report_propless(m, {:__aliases__, _, parts}) do
    if Enum.any?(Process.get(:propless), &(Enum.take(&1, -length(parts)) == parts)) do
      mod = Enum.join(parts, ".")

      report(m, "#{mod}.schema().properties rewritten to #{mod}.json_schema().properties, but #{mod} has no " <>
        "properties (object without properties or allOf): OpenApiSpex gave nil, so this schema was a " <>
        "pass-through object too (references/schemas.md, \"Object schemas without properties\")")
    end
  end

  defp report_propless(_m, _other), do: :ok

  # -- postwalk ----------------------------------------------------------------

  @schema_structs [[:Schema], [:OpenApiSpex, :Schema], [:Discriminator], [:OpenApiSpex, :Discriminator]]

  # %Schema{...} -> %{...}. The inner map was already visited by the postwalk.
  def post({:%, m, [{:__aliases__, _, path}, inner]} = node) do
    if path in @schema_structs do
      case inner do
        {:%{}, _, [{:|, _, _}]} ->
          report(m, "struct update `%Schema{base | key: value}` left as is: rewrite it as a schema map " <>
            "(references/schemas.md, \"Modules the script does not convert\")")
          node

        _ ->
          inner
      end
    else
      node
    end
  end

  # X.schema() -> X (module reference)
  def post({{:., _, [{:__aliases__, _, _} = a, :schema]}, _, []} = node) do
    if schema_call?(node), do: a, else: node
  end

  def post({kind, m, [{:__aliases__, am, [:OpenApiSpex]}]}) when kind in [:require, :import] do
    if Process.get(:needs_jsv),
      do: {:use, Keyword.put(m, :jsv_marker, true), [{:__aliases__, am, [:JSV, :Schema]}]},
      else: {:__drop__, m, nil}
  end

  def post({:use, m, [{:__aliases__, am, [:OpenApiSpex, :ControllerSpecs]} | _]}) do
    {:use, m, [{:__aliases__, am, [:Oaskit, :Controller]}]}
  end

  def post({:plug, m, [{:__aliases__, am, [:OpenApiSpex, :Plug, :CastAndValidate]} | rest]}) do
    old_opts =
      case rest do
        [o] -> keyword_pairs(o) || []
        _ -> []
      end

    replace_params = get_kv(old_opts, :replace_params)

    if replace_params == nil or unwrap(elem(replace_params, 1)) != false do
      report(m, "OpenApiSpex.Plug.CastAndValidate had replace_params: true (the default): actions may expect " <>
        "OpenApiSpex-cast `params`/`conn.body_params` (atom keys, structs). Oaskit leaves Phoenix params " <>
        "unchanged (references/controllers.md, \"Phoenix params vs cast values\")")
    end

    for {_, v} = pair <- old_opts, kw_key(pair) not in [:replace_params, :json_render_error_v2, :render_error] do
      report(m, "OpenApiSpex.Plug.CastAndValidate option #{kw_key(pair)}: #{Macro.to_string(v)} dropped " <>
        "(no equivalent option in Oaskit.Plugs.ValidateRequest)")
    end

    case get_kv(old_opts, :render_error) do
      nil ->
        :ok

      {_, renderer} ->
        handler = Process.get(:opts)[:error_handler] || "Oaskit.ErrorHandler.Default"

        report(m, ":render_error plug #{Macro.to_string(renderer)} replaced by error handler #{handler}: " <>
          "port it, it must call Plug.Conn.halt/1 (references/errors.md)")
    end

    handler_opts =
      case Process.get(:opts)[:error_handler] do
        nil -> []
        mod -> [{key(:error_handler), {:__aliases__, [], mod |> String.split(".") |> Enum.map(&String.to_atom/1)}}]
      end

    new_opts = handler_opts ++ [{key(:html_errors), lit(false)}]
    {:plug, m, [{:__aliases__, am, [:Oaskit, :Plugs, :ValidateRequest]}, new_opts]}
  end

  def post({:__block__, m, exprs}) when is_list(exprs) and length(exprs) > 1 do
    unused_jsv? = Enum.any?(exprs, &jsv_use?/1) and not needs_jsv_schema?(exprs)

    {kept, pending} =
      Enum.reduce(exprs, {[], []}, fn stmt, {acc, pending} ->
        if schema_alias?(stmt) or match?({:__drop__, _, _}, stmt) or (unused_jsv? and jsv_use?(stmt)) do
          {acc, pending ++ leading_comments(stmt)}
        else
          {[add_leading_comments(stmt, pending) | acc], []}
        end
      end)

    for %{text: text, line: line} <- pending,
        do: info(line, "comment removed with the statement below it: #{text}")

    {:__block__, m, kept |> Enum.reverse() |> move_use_up()}
  end

  def post({fun, m, [schema | rest]} = node) when is_list(m) do
    if spex_schema_fun?(node) do
      case schema_module_call(node, m, schema, rest) do
        ^node -> if m[:from_pipe], do: {:|>, [], [schema, {fun, Keyword.delete(m, :from_pipe), rest}]}, else: node
        converted -> converted
      end
    else
      post_other(node)
    end
  end

  def post(node), do: post_other(node)

  defp leading_comments({_, meta, _}) when is_list(meta), do: Keyword.get(meta, :leading_comments, [])
  defp leading_comments(_), do: []

  defp add_leading_comments(stmt, []), do: stmt

  defp add_leading_comments({f, meta, args}, comments) when is_list(meta),
    do: {f, Keyword.update(meta, :leading_comments, comments, &(comments ++ &1)), args}

  defp add_leading_comments(stmt, _), do: stmt

  defp schema_module_call(node, m, schema, rest) do
    case schema_module_opts(rest) do
      :none ->
        convert_schema_module(schema, m, node)

      :no_struct ->
        case schema do
          {:%{}, _, _} ->
            def_block(:json_schema, schema, m)

          _ ->
            convert_schema_module(schema, m, node)
        end

      :other ->
        report(m, "OpenApiSpex.schema/2 with options other than struct?: and derive?: left as is: rewrite by hand " <>
          "(references/schemas.md, \"Modules the script does not convert\")")

        node
    end
  end

  # derive?: false changes nothing (defschema derives no encoder). struct?: false
  # is a plain JSV schema module.
  defp schema_module_opts([]), do: :none

  defp schema_module_opts([opts]) do
    case keyword_pairs(opts) do
      nil ->
        :other

      pairs ->
        cond do
          Enum.any?(pairs, &(kw_key(&1) not in [:struct?, :derive?])) -> :other
          Enum.any?(pairs, &(kw_key(&1) == :struct? and unwrap(elem(&1, 1)) == false)) -> :no_struct
          true -> :none
        end
    end
  end

  defp schema_module_opts(_), do: :other

  defp post_other({:operation, m, [action, spec]}) when is_list(spec) do
    if Enum.any?(spec, &(kw_key(&1) == :security)) do
      report(m, "operation declares `security:`. Oaskit.Plugs.ValidateRequest answers 401 unless given " <>
        "a :security option (a plug, or false) (references/controllers.md, \"Security\")")
    end

    spec =
      Enum.map(spec, fn
        {k, v} = pair ->
          case kw_key(pair) do
            :responses -> {k, convert_responses(v, m)}
            :request_body -> {k, convert_request_body(v, m)}
            _ -> pair
          end
      end)

    {:operation, m, [action, spec]}
  end

  defp post_other({:%{}, m, kv} = node) when is_list(kv) do
    if kv != [] and Enum.all?(kv, &(match?({_, _}, &1) and kw_key(&1) != nil)) do
      {:%{}, m, convert_schema_map(kv, m)}
    else
      node
    end
  end

  defp post_other(node), do: node

  # Only aliases of Schema/Discriminator are removed; other OpenApiSpex aliases
  # (spec modules) are migrated by hand.
  defp schema_alias?({:alias, _, [{:__aliases__, _, [:OpenApiSpex, name]} | _]}),
    do: name in [:Schema, :Discriminator]

  defp schema_alias?({:alias, _, [{{:., _, [{:__aliases__, _, [:OpenApiSpex]}, :{}]}, _, names}]}) do
    Enum.all?(names, &match?({:__aliases__, _, [n]} when n in [:Schema, :Discriminator], &1))
  end

  defp schema_alias?(_), do: false

  defp convert_schema_module({:%{}, mm, kv} = schema, m, node) do
    type = kv |> get_kv(:type) |> then(&(&1 && unwrap(elem(&1, 1))))
    has_props = get_kv(kv, :properties) != nil
    composition? = Enum.any?([:allOf, :anyOf, :oneOf], &get_kv(kv, &1))

    cond do
      type == :object and has_props ->
        {:defschema, Keyword.delete(m, :closing), [schema]}

      is_list(type) and Enum.map(type, &unwrap/1) == [:object, :null] and has_props ->
        report(m, "top-level nullable object module: nullable removed, wrap each reference to this module " <>
          "with nullable(Module) (references/schemas.md, \"nullable\")")
        {:defschema, Keyword.delete(m, :closing), [{:%{}, mm, put_kv(kv, :type, lit(:object))}]}

      type == :object and not composition? ->
        info(m, "OpenApiSpex schema module with type: :object but no properties (OpenApiSpex returned the " <>
          "data unchanged): plain JSV schema module, defschema would cast to an empty struct " <>
          "(references/schemas.md, \"Object schemas without properties\")")
        def_block(:json_schema, schema, m)

      type == :object ->
        report(m, "OpenApiSpex schema module with type: :object, no properties and a composition " <>
          "(allOf, anyOf, oneOf): its content is rewritten but the OpenApiSpex.schema/1 call is kept, " <>
          "replace it by hand (references/schemas.md, \"Modules the script does not convert\")")
        node

      get_kv(kv, :allOf) ->
        report(m, "OpenApiSpex schema module with a top-level allOf: its content is rewritten but the " <>
          "OpenApiSpex.schema/1 call is kept, replace it by hand " <>
          "(references/schemas.md, \"Modules the script does not convert\")")
        node

      true ->
        def_block(:json_schema, schema, m)
    end
  end

  defp convert_schema_module(_other, m, node) do
    report(m, "OpenApiSpex.schema/1 argument is not a %{...} map literal (a variable or a function call), " <>
      "left as is (a bare schema(...) call from import OpenApiSpex too: it no longer compiles). Replace it with " <>
      "defschema(arg) when arg returns an object schema with properties, otherwise with " <>
      "def json_schema, do: arg (references/schemas.md, \"Schemas built by a function\")")
    node
  end

  defp convert_schema_map(kv, m) do
    kv =
      Enum.map(kv, fn pair ->
        if kw_key(pair) == :example, do: {key(:examples), list([elem(pair, 1)])}, else: pair
      end)

    case get_kv(kv, :nullable) do
      nil -> kv
      {_, v} -> convert_nullable(drop_kv(kv, :nullable), unwrap(v), m)
    end
  end

  defp convert_nullable(kv, false, _m), do: kv

  defp convert_nullable(kv, true, m) do
    cond do
      get_kv(kv, :allOf) ->
        {doc, rest} = Enum.split_with(kv, &(kw_key(&1) in @doc_keys))
        rest = drop_kv(rest, :type)

        inner =
          case rest do
            [{_, all_of}] ->
              case list_items(all_of) do
                [single] -> single
                _ -> map(rest)
              end

            _ ->
              map(rest)
          end

        doc ++ [{key(:anyOf), list([null_schema(), inner])}]

      pair = get_kv(kv, :anyOf) || get_kv(kv, :oneOf) ->
        {k, items} = pair
        kv = Enum.map(kv, fn p -> if p == pair, do: {k, list([null_schema() | list_items(items)])}, else: p end)
        nullable_type(kv, m, false)

      true ->
        nullable_type(kv, m, true)
    end
  end

  defp null_schema, do: map([{key(:type), lit(:null)}])

  defp nullable_type(kv, m, required_type?) do
    case get_kv(kv, :type) do
      {k, t} ->
        case unwrap(t) do
          t when is_atom(t) ->
            kv = Enum.map(kv, fn p -> if kw_key(p) == :type, do: {k, list([lit(t), lit(:null)])}, else: p end)
            add_nil_to_enum(kv, m)

          _ ->
            report(m, "nullable: true kept (JSV ignores it): type is not a literal atom, write " <>
              "type: [t, :null] by hand (references/schemas.md, \"nullable\")")
            kv ++ [{key(:nullable), lit(true)}]
        end

      nil when required_type? ->
        report(m, "nullable: true without type kept (JSV ignores it). OpenApiSpex did not validate values of " <>
          "a typeless schema: add a type, or drop nullable and the sub-schema keywords (items, properties…) " <>
          "which JSV applies even without type (references/schemas.md, \"nullable\")")
        kv ++ [{key(:nullable), lit(true)}]

      nil ->
        kv
    end
  end

  defp add_nil_to_enum(kv, m) do
    case get_kv(kv, :enum) do
      nil ->
        kv

      {ek, enum} ->
        case list_items(enum) || sigil_items(enum) do
          nil ->
            report(m, "nullable enum is not a literal list: type now includes :null but null is still rejected " <>
              "until nil is added to the enum by hand (references/schemas.md, \"nullable\")")

            kv

          items ->
            Enum.map(kv, fn p -> if kw_key(p) == :enum, do: {ek, list(items ++ [lit(nil)])}, else: p end)
        end
    end
  end

  # ~w(a b) and ~w(a b)a without interpolation
  defp sigil_items({:sigil_w, _, [{:<<>>, _, [str]}, mods]}) when is_binary(str) and mods in [[], ~c"s", ~c"a"] do
    words = String.split(str)
    if mods == ~c"a", do: Enum.map(words, &lit(String.to_atom(&1))), else: Enum.map(words, &lit/1)
  end

  defp sigil_items(_), do: nil

  # -- operations ----------------------------------------------------------------

  defp convert_responses({:%{}, m, items}, om), do: {:%{}, m, Enum.map(items, &convert_response(&1, om))}

  defp convert_responses({:__block__, m, [items]}, om) when is_list(items),
    do: {:__block__, m, [Enum.map(items, &convert_response(&1, om))]}

  defp convert_responses(items, om) when is_list(items), do: Enum.map(items, &convert_response(&1, om))

  defp convert_responses(other, om) do
    {converted, n} =
      Macro.prewalk(other, 0, fn
        {:{}, _, [desc, ct, _schema]} = tuple, n ->
          if is_binary(unwrap(desc)) and is_binary(unwrap(ct)),
            do: {convert_response_def(tuple, om), n + 1},
            else: {tuple, n}

        node, n ->
          {node, n}
      end)

    if n > 0 do
      report(om, "operation responses built by a function call: the {description, content_type, schema} " <>
        "tuples in its arguments were rewritten to Oaskit responses, change that function to take and return " <>
        "Oaskit responses (references/controllers.md, \"Responses built by a function\")")
    else
      report(om, "operation responses built by a function call, left as is: that function must return Oaskit " <>
        "responses (references/controllers.md, \"Responses built by a function\")")
    end

    converted
  end

  defp convert_response({code, resp}, om), do: {code, convert_response_def(resp, om)}

  defp convert_response_def({:{}, _, [desc, ct, schema]}, _om) do
    cond do
      unwrap(schema) == nil ->
        list([{key(:description), desc}])

      unwrap(ct) == "application/json" ->
        tuple2(schema, [{key(:description), desc}])

      true ->
        list([
          {key(:description), desc},
          {key(:content), map([{ct, list([{key(:schema), schema}])}])}
        ])
    end
  end

  defp convert_response_def({:__block__, _, [str]} = desc, _om) when is_binary(str) do
    list([{key(:description), desc}])
  end

  defp convert_response_def(other, om) do
    report(om, "operation response #{Macro.to_string(other) |> String.slice(0, 60)} left as is: expected " <>
      "{description, content_type, schema} or a description string (references/controllers.md, \"Mapping\")")
    other
  end

  defp convert_request_body({:{}, _, [desc, ct, schema]}, om) do
    report(om, "operation request_body {description, content_type, schema} was optional in OpenApiSpex, the " <>
      "rewritten {Schema, opts} is required: true. Keep it unless the endpoint accepts an empty body " <>
      "(references/controllers.md, \"Request bodies: the shortcut makes them required\")")
    request_body(desc, ct, schema, [], om)
  end

  defp convert_request_body({:{}, _, [desc, ct, schema, opts]}, om) do
    pairs = keyword_pairs(opts) || []

    if not Enum.any?(pairs, &(kw_key(&1) == :required)) do
      report(om, "operation request_body {description, content_type, schema, opts} without required: was " <>
        "optional in OpenApiSpex, the rewritten {User, opts} (Oaskit shortcut) is required: true. Keep it unless the endpoint " <>
        "accepts an empty body (references/controllers.md, \"Request bodies: the shortcut makes them required\")")
    end

    pairs = Enum.reject(pairs, &(kw_key(&1) == :required and unwrap(elem(&1, 1)) == true))
    request_body(desc, ct, schema, pairs, om)
  end

  defp convert_request_body(other, om) do
    report(om, "operation request_body #{Macro.to_string(other) |> String.slice(0, 60)} left as is: expected " <>
      "{description, content_type, schema} or {description, content_type, schema, opts} " <>
      "(references/controllers.md, \"Mapping\")")
    other
  end

  defp request_body(desc, ct, schema, extra, _om) do
    if unwrap(ct) == "application/json" do
      tuple2(schema, [{key(:description), desc} | extra])
    else
      required = if Enum.any?(extra, &(kw_key(&1) == :required)), do: [], else: [{key(:required), lit(true)}]

      list(
        [{key(:description), desc}, {key(:content), map([{ct, list([{key(:schema), schema}])}])}] ++
          required ++ extra
      )
    end
  end
end

C.run_files(files, opts, project, fmt_opts, &Rewrite.transform(&1, opts, propless))
