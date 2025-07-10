defmodule Oaskit.Spec.PathItem do
  use Oaskit.Internal.SpecObject

  def verbs do
    [:get, :put, :post, :delete, :options, :head, :patch, :trace]
  end

  defschema %{
    title: "PathItem",
    type: :object,
    description: "Describes operations available on a single path.",
    properties: %{
      summary: %{
        type: :string,
        description: "An optional string summary for all operations in this path."
      },
      description: %{
        type: :string,
        description: "An optional string description for all operations in this path."
      },
      get: Oaskit.Spec.Operation,
      put: Oaskit.Spec.Operation,
      post: Oaskit.Spec.Operation,
      delete: Oaskit.Spec.Operation,
      options: Oaskit.Spec.Operation,
      head: Oaskit.Spec.Operation,
      patch: Oaskit.Spec.Operation,
      trace: Oaskit.Spec.Operation,
      servers: %{
        type: :array,
        items: Oaskit.Spec.Server,
        description: "Alternative servers array for all operations in this path."
      },
      parameters: %{
        type: :array,
        items: %{anyOf: [Oaskit.Spec.Reference, Oaskit.Spec.Parameter]},
        description: "Parameters applicable for all operations under this path."
      }
    },
    required: []
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_subs(
      get: Oaskit.Spec.Operation,
      put: Oaskit.Spec.Operation,
      post: Oaskit.Spec.Operation,
      delete: Oaskit.Spec.Operation,
      options: Oaskit.Spec.Operation,
      head: Oaskit.Spec.Operation,
      patch: Oaskit.Spec.Operation,
      trace: Oaskit.Spec.Operation,
      servers: {:list, Oaskit.Spec.Server},
      parameters: {:list, {:or_ref, Oaskit.Spec.Parameter}}
    )
    |> collect()
  end

  defimpl Enumerable do
    alias Oaskit.Spec.PathItem

    def reduce(path_item, arg, fun) do
      # Take with ordering to avoid schema reference naming randomness
      by_verb =
        Enum.flat_map(PathItem.verbs(), fn k ->
          case Map.fetch!(path_item, k) do
            nil -> []
            v -> [{k, v}]
          end
        end)

      Enumerable.List.reduce(by_verb, arg, fun)
    end

    def member?(path_item, {k, v}) do
      case path_item do
        %{^k => ^v} -> {:ok, true}
        _ -> {:ok, false}
      end
    end

    def count(path_item) do
      {:ok, Enum.count(PathItem.verbs(), &(Map.fetch!(path_item, &1) != nil))}
    end

    def slice(_) do
      {:error, __MODULE__}
    end
  end
end
