defmodule OpenApify.Spec.Paths do
  require JSV
  use OpenApify.Internal.SpecObject

  # Holds the relative paths to individual endpoints and their operations.
  def schema do
    %{
      title: "Paths",
      type: :object,
      description:
        "Holds the relative paths to individual endpoints and their operations, mapping each path to a Path Item Object.",
      additionalProperties: %{anyOf: [OpenApify.Spec.Reference, OpenApify.Spec.PathItem]}
    }
  end

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      {:or_ref,
       fn value, ctx ->
         {_, _} = OpenApify.Internal.Normalizer.normalize!(value, OpenApify.Spec.PathItem, ctx)
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

    routes
    |> Stream.flat_map(&operation_route/1)
    |> Stream.filter(fn {route, _, _, _} -> user_filter.(route) end)
    |> Stream.map(fn {_route, path, verb, op} ->
      path = encode_router_path(path)
      {[Access.key(path, %{}), Access.key(verb, %{})], op}
    end)
    |> Enum.reduce(%{}, fn {access_path, op}, acc -> put_in(acc, access_path, op) end)
  end

  defp operation_route(route) do
    with %{path: path, plug: controller, plug_opts: action, verb: verb} when is_atom(action) <-
           route,
         true <- Code.ensure_loaded?(controller),
         true <- function_exported?(controller, :__open_apify__, 3),
         {:ok, op} <- controller.__open_apify__(:operation, action, verb) do
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
