defmodule Mix.Tasks.Openapi.Dump do
  alias CliMate.CLI
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

    module
    |> Oaskit.to_json!(%{
      pretty: opts.pretty,
      validation_error_handler: &handle_validation_error/1
    })
    |> output(opts)
  end

  defp handle_validation_error(verr) do
    CLI.warn("""
    Some errors were found when validating the OpenAPI speficication:

    #{Exception.format_banner(:error, verr)}
    """)
  end

  @doc false
  def to_module(arg) do
    mod = Module.concat([arg])

    case Code.ensure_loaded?(mod) do
      true -> {:ok, mod}
      false -> {:error, "could not find module #{arg}"}
    end
  end

  defp output(json, %{output: out_path}) do
    Mix.Generator.create_file(out_path, json, force: true)
  end
end
