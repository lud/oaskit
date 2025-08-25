defmodule Oaskit.SpecDumper do
  alias JSV.Codec

  @moduledoc """
  A helper to render an OpenAPI specification to JSON format.
  """

  @doc """
  Returns a JSON representation of the given OpenAPI specification. The
  specification must be in normal form (binary keys, no atoms besides booleans
  and `nil`).

  ### Options

  * `:pretty` - A boolean to control JSON pretty printing. JSON object keys will
    be ordered if the available JSON library (`Jason`, `JSON`) supports it. Key
    ordering is custom (for instance, the `openapi` key is always first).
  * `:validation_error_handler` - A function accepting a `JSV.ValidationError`
    struct. The JSON generation does not fail on validation error unless you
    raise from that function.
  """
  def to_json!(normal_spec, opts \\ []) do
    opts = Map.new(opts)

    normal_spec
    |> validate(opts)
    |> prune()
    |> encode(opts)
  end

  defp validate(spec, opts) do
    _ =
      case Oaskit.SpecValidator.validate(spec) do
        {:ok, _} -> :ok
        {:error, verr} -> handle_error(verr, opts)
      end

    spec
  end

  defp handle_error(verr, opts) do
    case opts[:validation_error_handler] do
      f when is_function(f) -> f.(verr)
      _ -> :ok
    end
  end

  defp prune(spec) do
    JSV.Helpers.Traverse.prewalk(spec, fn
      {:val, map} when is_map(map) -> Map.delete(map, "jsv-cast")
      other -> elem(other, 1)
    end)
  end

  defp encode(spec, %{pretty: true}) do
    cond do
      typefix(Codec.supports_ordered_formatting?()) ->
        Codec.format_ordered_to_iodata!(spec, &key_sorter/2)

      typefix(Codec.supports_formatting?()) ->
        Codec.format_to_iodata!(spec)

      :other ->
        raise ArgumentError, "Pretty printing is not supported by #{Codec.codec()}."
    end
  end

  defp encode(spec, %{}) do
    Codec.encode!(spec)
  end

  @key_order Map.new(
               Enum.with_index([
                 "openapi",
                 "title",
                 "info",
                 "tags",
                 "servers",
                 "security",
                 "components",
                 "schemas",
                 "responses",
                 "paths"
               ])
             )

  defp key_order do
    @key_order
  end

  defp key_sorter(a, b) do
    Map.get(key_order(), a, a) <= Map.get(key_order(), b, b)
  end

  defp typefix(v) do
    Process.get(__ENV__.function, v)
  end
end
