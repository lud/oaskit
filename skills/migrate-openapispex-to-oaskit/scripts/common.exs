# Shared helpers for the rewrite scripts. Loaded with Code.require_file/1.
#
# Every rewrite script:
#   * takes --project PATH (default ".") and optional file/dir arguments
#     (relative to the project, default given by the script);
#   * is a dry run unless --write is given;
#   * prints CHANGED lines for files it would rewrite, REPORT lines for things
#     a human/agent must decide or do by hand, and INFO lines for what it did
#     that is worth knowing (nothing to do).

defmodule Migration.Common do
  def parse_args!(argv, extra_switches, default_paths) do
    {opts, args} =
      OptionParser.parse!(argv, strict: [project: :string, write: :boolean] ++ extra_switches)

    project = Path.expand(opts[:project] || ".")
    paths = if args == [], do: default_paths, else: args

    files =
      paths
      |> Enum.flat_map(fn p ->
        abs = Path.expand(p, project)

        cond do
          File.dir?(abs) -> Path.wildcard(Path.join(abs, "**/*.{ex,exs}"))
          File.regular?(abs) -> [abs]
          true -> Path.wildcard(abs)
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()

    {opts, project, files}
  end

  # Sourceror must not format from inside the project directory (it would try
  # to load the project's .formatter.exs and its import_deps), so the
  # formatter options are read here from the project's .formatter.exs and the
  # exported options of its import_deps (deps/<dep>/.formatter.exs), and the
  # script then works from a temporary directory.
  def formatter_opts!(project) do
    {opts, _} = read_formatter(Path.join(project, ".formatter.exs"))

    from_deps =
      opts
      |> Keyword.get(:import_deps, [])
      |> Enum.flat_map(fn dep ->
        case read_formatter(Path.join([project, "deps", to_string(dep), ".formatter.exs"])) do
          {dep_opts, true} -> get_in(dep_opts, [:export, :locals_without_parens]) || []
          {_, false} -> []
        end
      end)

    extra = [
      operation: 1,
      operation: 2,
      use_operation: 2,
      use_operation: 3,
      parameter: 2,
      tags: 1,
      defschema: 1,
      defschema: 2,
      defschema: 3,
      plug: 1,
      plug: 2
    ]

    lwp = Enum.uniq(Keyword.get(opts, :locals_without_parens, []) ++ from_deps ++ extra)

    File.cd!(System.tmp_dir!())
    [locals_without_parens: lwp, line_length: Keyword.get(opts, :line_length, 98)]
  end

  defp read_formatter(path) do
    if File.regular?(path) do
      {opts, _} = Code.eval_file(path)
      {opts, true}
    else
      {[], false}
    end
  end

  def rel(file), do: Path.relative_to(file, Process.get(:migration_project))

  def report(meta, msg), do: print_once("REPORT", meta, msg)
  def info(meta, msg), do: print_once("INFO", meta, msg)

  # Inside run_files/5, REPORT and INFO lines are collected and printed at the
  # end, one group per message (see flush_messages/0).
  defp print_once(prefix, meta, msg) do
    line = if is_list(meta), do: meta[:line], else: meta
    location = "#{rel(Process.get(:migration_file))}:#{line}"
    entry = {prefix, location, msg}
    seen = Process.get(:migration_reported, MapSet.new())

    if not MapSet.member?(seen, entry) do
      Process.put(:migration_reported, MapSet.put(seen, entry))

      case Process.get(:migration_buffer) do
        nil -> IO.puts("#{prefix} #{location} #{msg}")
        buffer -> Process.put(:migration_buffer, [entry | buffer])
      end
    end
  end

  # A message given for several locations is printed once, with the count and
  # the locations below it.
  defp flush_messages do
    entries = Process.get(:migration_buffer) |> Enum.reverse()
    Process.delete(:migration_buffer)
    if entries != [], do: IO.puts("")

    entries
    |> Enum.group_by(fn {prefix, _, msg} -> {prefix, msg} end)
    |> Enum.sort_by(fn {{prefix, _}, [first | _]} ->
      {if(prefix == "REPORT", do: 0, else: 1), Enum.find_index(entries, &(&1 == first))}
    end)
    |> Enum.each(fn
      {{prefix, msg}, [{_, location, _}]} ->
        IO.puts("#{prefix} #{location} #{msg}")

      {{prefix, msg}, group} ->
        IO.puts("#{prefix} (#{length(group)} places) #{msg}")
        Enum.each(group, fn {_, location, _} -> IO.puts("#{prefix}   #{location}") end)
    end)
  end

  # Applies `transform` (AST -> AST) to each file. Writes only with --write.
  def run_files(files, opts, project, fmt_opts, transform) do
    Process.put(:migration_project, project)
    Process.put(:migration_buffer, [])

    changed =
      Enum.count(files, fn file ->
        Process.put(:migration_file, file)
        src = File.read!(file)

        case transform.(src) do
          :skip ->
            false

          ast ->
            out = Sourceror.to_string(ast, fmt_opts) <> "\n"

            if out != src do
              IO.puts("CHANGED #{rel(file)}")
              if opts[:write], do: File.write!(file, out)
              true
            else
              false
            end
        end
      end)

    flush_messages()
    mode = if opts[:write], do: "rewritten", else: "would be rewritten (dry run, pass --write)"
    IO.puts("\n#{changed} file(s) #{mode}. Run `mix format` in the project afterwards.")
  end

  # -- Sourceror AST helpers -------------------------------------------------

  def unwrap({:__block__, _, [v]}), do: v
  def unwrap(v), do: v

  def kw_key({k, _}) do
    case unwrap(k) do
      a when is_atom(a) -> a
      _ -> nil
    end
  end

  def kw_key(_), do: nil

  def get_kv(kv, key), do: Enum.find(kv, &(kw_key(&1) == key))
  def drop_kv(kv, key), do: Enum.reject(kv, &(kw_key(&1) == key))
  def key(atom), do: {:__block__, [format: :keyword], [atom]}
  def lit(v), do: {:__block__, [], [v]}
  def list(items), do: {:__block__, [], [items]}
  def map(kv), do: {:%{}, [], kv}
  def tuple2(a, b), do: {:__block__, [], [{a, b}]}

  def list_items({:__block__, _, [items]}) when is_list(items), do: items
  def list_items(items) when is_list(items), do: items
  def list_items(_), do: nil

  def keyword_pairs({:__block__, _, [items]}) when is_list(items), do: items
  def keyword_pairs(items) when is_list(items), do: items
  def keyword_pairs(_), do: nil

  def put_kv(kv, k, value) do
    if get_kv(kv, k) do
      Enum.map(kv, fn pair -> if kw_key(pair) == k, do: {elem(pair, 0), value}, else: pair end)
    else
      kv ++ [{key(k), value}]
    end
  end

  def alias_name({:__aliases__, _, parts}), do: Enum.map_join(parts, ".", &to_string/1)
  def alias_name(other), do: Macro.to_string(other)

  # def name do body end (block form, not `def(name, do: body)`)
  def def_block(name, body, meta \\ []) do
    line = meta[:line]
    meta = Keyword.take(meta, [:line, :leading_comments]) ++ [do: [line: line], end: [line: line]]
    {:def, meta, [{name, [line: line], nil}, [{{:__block__, [line: line], [:do]}, body}]]}
  end
end
