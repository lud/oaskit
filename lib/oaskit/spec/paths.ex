defmodule Oaskit.Spec.Paths do
  use Oaskit.Internal.SpecObject

  @deprecated "use #{inspect(__MODULE__)}.json_schema/0 instead"
  @doc false
  def schema do
    json_schema()
  end

  def json_schema do
    %{
      title: "Paths",
      type: :object,
      description:
        "Holds the relative paths to individual endpoints and their operations, mapping each path to a Path Item Object.",
      additionalProperties: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.PathItem]}
    }
  end

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      {:or_ref,
       fn value, ctx ->
         {_, _} = Oaskit.Internal.Normalizer.normalize!(value, Oaskit.Spec.PathItem, ctx)
       end}
    )
    |> collect()
  end

  @doc """
  Accepts a Phoenix router module and returns paths that point to a controller
  with operations defined for its actions.

  ### Options

  * `:filter` - A predicate function to limit routes defined in your OpenAPI
    specification. This predicate is not called for every route, only on routes
    that define an operation.
  * `:unprefix` - A string to remove from the beginning of the paths keys.
    Useful if your server path already contains a prefix like `"/api/v1"`. In
    the OpenAPI Specification, paths are always relative to the server path,
    even when starting with `"/"`.
  """
  def from_router(router, opts \\ []) when is_atom(router) do
    from_routes(router.__routes__(), opts)
  end

  @doc """
  Same as `from_router/2` but directly accepts the return value of
  `router_module.__routes__()`.
  """
  def from_routes(routes, opts \\ []) do
    user_filter = Keyword.get(opts, :filter, fn _ -> true end)

    unprefix =
      case Keyword.fetch(opts, :unprefix) do
        {:ok, prefix} when is_binary(prefix) -> fn path -> String.trim_leading(path, prefix) end
        :error -> & &1
      end

    routes
    |> Stream.flat_map(&operation_route/1)
    |> Stream.filter(fn {route, _, _, _} -> user_filter.(route) end)
    |> Stream.map(fn {_route, path, verb, op} ->
      path = encode_router_path(path)
      {[Access.key(unprefix.(path), %{}), Access.key(verb, %{})], op}
    end)
    |> Enum.reduce(%{}, fn {access_path, op}, acc -> put_in(acc, access_path, op) end)
  end

  defp operation_route(route) do
    with %{path: path, plug: controller, plug_opts: action, verb: verb} when is_atom(action) <-
           route,
         true <- Code.ensure_loaded?(controller),
         true <- function_exported?(controller, :__oaskit__, 3),
         {:ok, op} <- controller.__oaskit__(:operation, action, verb) do
      [{route, path, verb, op}]
    else
      _ -> []
    end
  end

  defp encode_router_path(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", fn
      ":" <> param -> "{#{param}}"
      segment -> segment
    end)
  end
end
