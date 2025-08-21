defmodule Oaskit.MixProject do
  use Mix.Project

  @source_url "https://github.com/lud/oaskit"
  @version "0.3.1"

  def project do
    [
      app: :oaskit,
      version: @version,
      source_url: @source_url,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps(),
      dialyzer: dialyzer(),
      modkit: modkit(),
      versioning: versioning()
    ]
  end

  defp elixirc_paths(env) do
    case env do
      :prod -> ["lib"]
      _ -> ["lib", "test/support"]
    end
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jsv, "~> 0.10"},
      {:plug, ">= 1.16.0"},
      {:decimal, "~> 2.0", optional: true},
      {:abnf_parsec, "~> 2.0", optional: true},
      {:cli_mate, "~> 0.8.1"},

      # Test
      {:bandit, "~> 1.0", only: [:dev, :test]},
      {:jason, "~> 1.0", only: [:dev, :test]},

      # Dev
      {:phoenix, ">= 1.7.0", only: [:dev, :test]},
      {:readmix, "~> 0.3", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: [:dev, :test, :doc], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "A set of macros and plugs for Elixir/Phoenix applications to automatically " <>
      "validate incoming HTTP requests based on the OpenAPI Specification v3.1."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib priv .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      extra_section: "GUIDES",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: doc_extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules(),
      groups_for_modules: groups_for_modules(),
      nest_modules_by_prefix: [Oaskit.Spec]
    ]
  end

  def doc_extras do
    existing_guides = Path.wildcard("guides/**/*.md")

    defined_guides = [
      "CHANGELOG.md",
      "README.md",
      "guides/quickstart.md",
      "guides/external-specs.md"
    ]

    case existing_guides -- defined_guides do
      [] ->
        :ok
        defined_guides

      missed ->
        IO.warn("""

        unreferenced guides

        #{Enum.map(missed, &[inspect(&1), ",\n"])}


        """)

        defined_guides ++ missed
    end
  end

  defp groups_for_extras do
    [
      Schemas: ~r/guides\/schemas\/.?/,
      Build: ~r/guides\/build\/.?/,
      Validation: ~r/guides\/validation\/.?/
    ]
  end

  defp groups_for_modules do
    [
      "Main API": [Oaskit, Oaskit.Controller],
      Plugs: [~r{Oaskit\.Plugs\.}, Oaskit.SpecController],
      "Error Handling": ~r{Oaskit\.ErrorHandler},
      Testing: [Oaskit.Test],
      "OpenAPI Spec 3.1": ~r{Oaskit\.Spec\.},
      Validation: ~r{Oaskit\.Validation\.},
      Parsers: ~r{Oaskit\.Parsers\.},
      "JSON Schema Extensions": ~r{Oaskit\.JsonSchema\.}
    ]
  end

  def cli do
    [
      preferred_envs: [
        dialyzer: :test,
        "oapi.phx.test": :test
      ]
    ]
  end

  defp dialyzer do
    [
      flags: [:unmatched_returns, :error_handling, :unknown, :extra_return],
      list_unused_filters: true,
      plt_add_deps: :app_tree,
      plt_add_apps: [:ex_unit, :mix, :jsv],
      plt_local_path: "_build/plts"
    ]
  end

  defp modkit do
    [
      mount: [
        {Oaskit.TestWeb, "test/support/test_web", flavor: :phoenix},
        {Oaskit.ConnCase, "test/support/conn_case"},
        {Oaskit, "lib/oaskit"},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task},
        {Plug, "test/support/test_web/plug"},
        {Mix.Tasks.Oapi, :ignore}
      ]
    ]
  end

  defp versioning do
    [
      annotate: true,
      before_commit: [
        &readmix/1,
        {:add, "README.md"},
        {:add, "guides"},
        &gen_changelog/1,
        {:add, "CHANGELOG.md"}
      ]
    ]
  end

  def readmix(vsn) do
    rdmx = Readmix.new(vars: %{app_vsn: vsn})
    :ok = Readmix.update_file(rdmx, "README.md")

    :ok =
      Enum.each(Path.wildcard("guides/**/*.md"), fn path ->
        :ok = Readmix.update_file(rdmx, path)
      end)
  end

  defp gen_changelog(vsn) do
    case System.cmd("git", ["cliff", "--tag", vsn, "-o", "CHANGELOG.md"], stderr_to_stdout: true) do
      {_, 0} -> IO.puts("Updated CHANGELOG.md with #{vsn}")
      {out, _} -> {:error, "Could not update CHANGELOG.md:\n\n #{out}"}
    end
  end
end
