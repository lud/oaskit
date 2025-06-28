defmodule Mix.Tasks.Openapi.Dump do
  alias CliMate.CLI
  alias JSV.Codec
  use Mix.Task

  @command [
    module: __MODULE__,
    arguments: [
      module: [
        type: :string,
        doc: """
        An Elixir module with a `spec/0` callback returning an OpenAPI
        specification.
        """,
        cast: {__MODULE__, :to_module, []}
      ]
    ],
    options: [
      output: [
        type: :string,
        short: :o,
        default: "openapi.json",
        doc: "The desired output file path.",
        doc_arg: "path/to/file.json"
      ],
      pretty: [
        type: :boolean,
        default: true,
        doc: "JSON pretty-printing."
      ]
    ]
  ]

  @requirements ["app.config"]
  @shortdoc "Writes an OpenAPI specification in a JSON file."

  @moduledoc """
  #{@shortdoc}

  #{CliMate.CLI.format_usage(@command, format: :moduledoc)}
  """

  def run(argv) do
    %{arguments: %{module: module}, options: opts} = CLI.parse_or_halt!(argv, @command)

    module.spec()
    |> Oaskit.normalize_spec!()
    |> validate()
    |> prune()
    |> encode(opts)
    |> output(opts)
  end

  @doc false
  def to_module(arg) do
    mod = Module.concat([arg])

    case Code.ensure_loaded?(mod) do
      true -> {:ok, mod}
      false -> {:error, "could not find module #{arg}"}
    end
  end

  defp validate(spec) do
    _ =
      case Oaskit.Internal.SpecValidator.validate(spec) do
        {:ok, _} ->
          :ok

        {:error, verr} ->
          CLI.warn("""
          Some errors were found when validating the OpenAPI speficication:

          #{Exception.format_banner(:error, verr)}
          """)
      end

    spec
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

  defp encode(spec, _) do
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

  defp output(json, %{output: out_path}) do
    Mix.Generator.create_file(out_path, json, force: true)
  end

  defp typefix(v) do
    Process.get(make_ref(), v)
  end
end
