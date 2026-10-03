# Replaces `OpenApiSpex.TestAssertions.assert_schema/3` checks with the
# valid_response helper, a function of your ConnCase wrapping
# `Oaskit.Test.valid_response/3` (see references/testing.md).
#
#     elixir rewrite_tests.exs --project path/to/app [--helper valid_response] [--wrapper NAME]... [--write] [paths...]
#
# --helper NAME   name of the valid_response helper function (default: valid_response).
# --wrapper NAME  a test helper of the project wrapping assert_schema, called as
#                 NAME(conn, status, ...) or conn |> NAME(status, ...): its calls
#                 become helper(conn, status), the other arguments (schema
#                 title, spec...) are dropped. Can be given several times.
# --write         apply the changes (dry run otherwise).
# paths           files or directories relative to --project (default: test).
#
# For each `assert_schema(var, "Title", MyAppWeb.ApiSpec.spec())` (also inside
# `Enum.each(var, &assert_schema(&1, ...))`), it looks in the same block for
# the assignment `var = ... |> json_response(status)` (or
# `json_response(conn, status)`), replaces `json_response` with the helper
# (`valid_response` by default, it must exist in your ConnCase, see
# references/testing.md) and removes the assert_schema statement.
# Cases it cannot pair are printed as REPORT lines and left untouched.
# Then it drops the `var =` binding when `var` is not used after it in the
# block, and removes the `alias` of modules that only appeared in the removed
# assert_schema calls (usually the spec module).
#
# This rewrite is not purely syntactic: valid_response checks the response
# against the operation that served the request, which is stricter than
# assert_schema. Expect new test failures that reveal mistakes in the OpenAPI
# document.

Mix.install([{:sourceror, "~> 1.7"}])
Code.require_file("common.exs", __DIR__)
alias Migration.Common, as: C

{opts, project, files} =
  C.parse_args!(System.argv(), [helper: :string, wrapper: :keep], ["test"])
fmt_opts = C.formatter_opts!(project)

defmodule RewriteTests do
  import Migration.Common

  def transform(src, helper, wrappers) do
    if String.contains?(src, "assert_schema") or String.contains?(src, "OpenApiSpex") or
         Enum.any?(wrappers, &String.contains?(src, to_string(&1))) do
      Process.put(:helper, String.to_atom(helper))
      Process.put(:wrappers, wrappers)
      Process.put(:removed_aliases, MapSet.new())

      src
      |> Sourceror.parse_string!()
      |> Macro.prewalk(&tag_wrapper_def/1)
      |> Macro.postwalk(&post/1)
      |> remove_unused_aliases()
    else
      :skip
    end
  end

  def post({:__block__, m, exprs}) when is_list(exprs) do
    exprs =
      reject_keeping_blank_lines(exprs, fn
        {:import, im, [{:__aliases__, _, [:OpenApiSpex | _] = mod} | _]} ->
          info(im, "removed import of #{Enum.join(mod, ".")}")
          true

        _ ->
          false
      end)

    {:__block__, m, rewrite_block(exprs)}
  end

  # conn |> wrapper(status, ...) -> conn |> helper(status)
  def post({:|>, m, [conn, {name, m2, [status | rest]}]} = node) when is_atom(name) and is_list(m2) do
    if name in Process.get(:wrappers) and !m2[:wrapper_def] and wrapper_rest_ok?(rest, m2) do
      note_status(status, m2)
      {:|>, m, [conn, {Process.get(:helper), m2, [status]}]}
    else
      node
    end
  end

  # wrapper(conn, status, ...) -> helper(conn, status)
  def post({name, m, [conn, status | rest]} = node) when is_atom(name) and is_list(m) do
    if name in Process.get(:wrappers) and !m[:wrapper_def] and wrapper_rest_ok?(rest, m) do
      note_status(status, m)
      {Process.get(:helper), m, [conn, status]}
    else
      node
    end
  end

  def post(node), do: node

  # The schema title only. More arguments (options such as a spec given
  # explicitly) usually mean that the conn did not go through the validation
  # plug.
  defp wrapper_rest_ok?(rest, m) do
    if length(rest) <= 1 do
      true
    else
      report(m, "call with arguments after the schema title left as is: an explicit spec or option often means " <>
        "that the conn did not go through the validation plug (references/testing.md, \"When to keep " <>
        "json_response/2\")")

      false
    end
  end

  defp note_status(status, m) do
    if unwrap(status) in [401, 403, :unauthorized, :forbidden] do
      info(m, "#{inspect(unwrap(status))} response checked with #{Process.get(:helper)}: if a router pipeline " <>
        "plug sends it, the conn was not validated and the helper raises, keep json_response/2 " <>
        "(references/testing.md, \"When to keep json_response/2\")")
    end
  end

  # The head of a wrapper definition looks like a call: mark it.
  defp tag_wrapper_def({kind, m, [head | rest]}) when kind in [:def, :defp],
    do: {kind, m, [tag_head(head) | rest]}

  defp tag_wrapper_def(node), do: node

  defp tag_head({:when, m, [head | guards]}), do: {:when, m, [tag_head(head) | guards]}

  defp tag_head({name, m, args}) when is_atom(name) and is_list(m) and is_list(args) do
    if name in Process.get(:wrappers) do
      report(m, "definition of #{name}/#{length(args)}, whose calls are rewritten to #{Process.get(:helper)}: " <>
        "remove it once no test calls it (references/testing.md, \"Helpers wrapping assert_schema\")")

      {name, Keyword.put(m, :wrapper_def, true), args}
    else
      {name, m, args}
    end
  end

  defp tag_head(head), do: head

  defp rewrite_block(exprs) do
    exprs
    |> Enum.with_index()
    |> Enum.flat_map(fn {stmt, i} ->
      case find_assert_schema(stmt) do
        nil -> []
        {var, meta} -> [{i, var, meta}]
      end
    end)
    |> Enum.reduce(exprs, fn {i, var, meta}, exprs ->
      case find_assignment(exprs, i, var) do
        nil ->
          msg =
            if var == :__unknown__,
              do: "assert_schema on a value that is not a variable",
              else: "assert_schema on `#{var}`: no `#{var} = ... json_response(...)` found in the same block"

          report(meta, msg <> ", migrate by hand (references/testing.md, \"Rewriting assert_schema/3\" " <>
            "and \"When to keep json_response/2\"). In a test helper wrapping assert_schema, rewrite its calls " <>
            "with --wrapper NAME instead (\"Helpers wrapping assert_schema\")")

          exprs

        j ->
          removed = Enum.at(exprs, i)
          report_removed_comments(removed, meta)
          collect_aliases(removed)

          exprs
          |> List.update_at(j, fn
            {:__patched__, _, _} = patched -> patched
            stmt -> {:__patched__, var, patch_assignment(stmt, var)}
          end)
          |> List.replace_at(i, :__removed__)
      end
    end)
    |> Enum.reject(&(&1 == :__removed__))
    |> drop_unused_bindings()
  end

  # `var = expr` -> `expr` when var is not used by the next statements.
  defp drop_unused_bindings(exprs) do
    plain = Enum.map(exprs, fn {:__patched__, _, stmt} -> stmt; stmt -> stmt end)

    exprs
    |> Enum.with_index()
    |> Enum.map(fn
      {{:__patched__, var, {:=, _, [{var, _, ctx}, rhs]} = stmt}, i} when is_atom(ctx) ->
        if uses_var?(Enum.drop(plain, i + 1), var), do: stmt, else: rhs

      {{:__patched__, _, stmt}, _} ->
        stmt

      {stmt, _} ->
        stmt
    end)
  end

  defp uses_var?(ast, var) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {^var, _, ctx} = n, _ when is_atom(ctx) -> {n, true}
        n, acc -> {n, acc}
      end)

    found
  end

  defp collect_aliases(stmt) do
    {_, names} =
      Macro.prewalk(stmt, Process.get(:removed_aliases), fn
        {:__aliases__, _, [name | _]} = n, acc when is_atom(name) -> {n, MapSet.put(acc, name)}
        n, acc -> {n, acc}
      end)

    Process.put(:removed_aliases, names)
  end

  # Removes `alias A.B.Name` (or `alias A.B, as: Name`) when Name appeared in a
  # removed assert_schema call and is no longer referenced in the file.
  defp remove_unused_aliases(ast) do
    candidates = Process.get(:removed_aliases)

    if MapSet.size(candidates) == 0 do
      ast
    else
      without = Macro.prewalk(ast, &if(aliased_name(&1) in candidates, do: nil, else: &1))

      {_, used} =
        Macro.prewalk(without, MapSet.new(), fn
          {:__aliases__, _, [name | _]} = n, acc when is_atom(name) -> {n, MapSet.put(acc, name)}
          n, acc -> {n, acc}
        end)

      Macro.postwalk(ast, fn
        {:__block__, m, exprs} when is_list(exprs) ->
          {:__block__, m,
           reject_keeping_blank_lines(exprs, fn stmt ->
             name = aliased_name(stmt)

             if name in candidates and name not in used do
               info(elem(stmt, 1), "removed alias #{name}, only used by the removed assert_schema calls")
               true
             end
           end)}

        n ->
          n
      end)
    end
  end

  # A removed statement followed by a blank line passes the blank line to the
  # previous statement.
  defp reject_keeping_blank_lines(exprs, reject?) do
    exprs
    |> Enum.reduce([], fn stmt, acc ->
      cond do
        !reject?.(stmt) -> [stmt | acc]
        acc == [] -> acc
        true -> [carry_newlines(hd(acc), stmt) | tl(acc)]
      end
    end)
    |> Enum.reverse()
  end

  defp carry_newlines({f, pm, a}, {_, rm, _}) when is_list(pm) and is_list(rm) do
    case get_in(rm, [:end_of_expression, :newlines]) do
      n when is_integer(n) and n > 1 ->
        eoe = Keyword.get(pm, :end_of_expression, [])
        eoe = Keyword.put(eoe, :newlines, max(n, Keyword.get(eoe, :newlines, 1)))
        {f, Keyword.put(pm, :end_of_expression, eoe), a}

      _ ->
        {f, pm, a}
    end
  end

  defp carry_newlines(prev, _), do: prev

  defp aliased_name({:alias, _, [{:__aliases__, _, parts}]}) when is_list(parts), do: List.last(parts)

  defp aliased_name({:alias, _, [{:__aliases__, _, _}, opts]}) when is_list(opts) do
    Enum.find_value(opts, fn
      {{:__block__, _, [:as]}, {:__aliases__, _, [name]}} -> name
      {:as, {:__aliases__, _, [name]}} -> name
      _ -> nil
    end)
  end

  defp aliased_name(_), do: nil

  defp report_removed_comments({_, stmt_meta, _}, meta) when is_list(stmt_meta) do
    for %{text: text} <- Keyword.get(stmt_meta, :leading_comments, []),
        do: info(meta, "removed the comment above the assert_schema call with it: #{text}")
  end

  defp report_removed_comments(_, _), do: :ok

  defp find_assert_schema(stmt) do
    {_, found} =
      Macro.prewalk(stmt, nil, fn
        {{:., _, [{:__aliases__, _, [:Enum]}, :each]}, m, [{coll, _, ctx}, fun]} = n, nil
        when is_atom(coll) and is_atom(ctx) ->
          if contains_assert_schema?(fun), do: {n, {coll, m}}, else: {n, nil}

        {:assert_schema, m, [{var, _, ctx} | _]} = n, nil when is_atom(var) and is_atom(ctx) ->
          {n, {var, m}}

        {:assert_schema, m, _} = n, nil ->
          {n, {:__unknown__, m}}

        {{:., _, [{:__aliases__, _, [:OpenApiSpex, :TestAssertions]}, :assert_schema]}, m, [{var, _, ctx} | _]} = n, nil
        when is_atom(var) and is_atom(ctx) ->
          {n, {var, m}}

        {{:., _, [{:__aliases__, _, [:OpenApiSpex, :TestAssertions]}, :assert_schema]}, m, _} = n, nil ->
          {n, {:__unknown__, m}}

        n, acc ->
          {n, acc}
      end)

    found
  end

  defp contains_assert_schema?(ast) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {:assert_schema, _, _} = n, _ -> {n, true}
        {{:., _, [{:__aliases__, _, [:OpenApiSpex, :TestAssertions]}, :assert_schema]}, _, _} = n, _ -> {n, true}
        n, acc -> {n, acc}
      end)

    found
  end

  defp find_assignment(exprs, i, var) do
    exprs
    |> Enum.take(i)
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.find_value(fn
      {{:__patched__, ^var, _}, j} -> j
      {stmt, j} -> if json_response_assignment?(stmt, var), do: j
    end)
  end

  defp json_response_assignment?(stmt, var) do
    case assignment(stmt, var) do
      nil -> false
      rhs -> json_response_call?(rhs)
    end
  end

  defp assignment({:assert, _, [inner]}, var), do: assignment(inner, var)

  defp assignment({:=, _, [lhs, rhs]}, var) do
    cond do
      binds?(lhs, var) -> rhs
      match?({:=, _, _}, rhs) -> assignment(rhs, var)
      true -> nil
    end
  end

  defp assignment(_, _), do: nil

  defp binds?({var, _, ctx}, var) when is_atom(ctx), do: true
  defp binds?(_, _), do: false

  defp json_response_call?({:|>, _, [_, {:json_response, _, [_status]}]}), do: true
  defp json_response_call?({:json_response, _, [_conn, _status]}), do: true
  defp json_response_call?(_), do: false

  defp patch_assignment({:assert, m, [inner]}, var), do: {:assert, m, [patch_assignment(inner, var)]}

  defp patch_assignment({:=, m, [lhs, rhs]}, var) do
    if binds?(lhs, var),
      do: {:=, m, [lhs, patch_rhs(rhs)]},
      else: {:=, m, [lhs, patch_assignment(rhs, var)]}
  end

  defp patch_rhs({:|>, m, [left, {:json_response, m2, [status] = args}]}) do
    note_status(status, m2)
    {:|>, m, [left, {Process.get(:helper), m2, args}]}
  end

  defp patch_rhs({:json_response, m, [_conn, status] = args}) do
    note_status(status, m)
    {Process.get(:helper), m, args}
  end
end

helper = opts[:helper] || "valid_response"
wrappers = opts |> Keyword.get_values(:wrapper) |> Enum.map(&String.to_atom/1)
C.run_files(files, opts, project, fmt_opts, &RewriteTests.transform(&1, helper, wrappers))
IO.puts("Then fix the unused aliases/variables that the compiler still reports.")
