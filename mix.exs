defmodule OpenApify.MixProject do
  use Mix.Project

  @source_url "https://github.com/lud/open_apify"
  @version "0.1.0"

  def project do
    [
      app: :open_apify,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: docs(),
      deps: deps(),
      dialyzer: dialyzer(),
      modkit: modkit()
    ]
  end

  defp elixirc_paths(noweb) when noweb in [:prod, :doc] do
    ["lib"]
  end

  defp elixirc_paths(_) do
    ["lib", "test/support"]
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
      {:jsv, "~> 0.8"},
      {:phoenix, ">= 1.7.0"},
      {:decimal, "~> 2.0", optional: true},
      {:abnf_parsec, "~> 2.0", optional: true},
      {:cli_mate, "~> 0.8.1"},

      # Dev
      {:libdev, "~> 0.1.0", only: [:dev, :test, :doc], runtime: false},
      {:readmix, "~> 0.3", only: [:dev, :test], runtime: false},

      # Test
      {:bandit, "~> 1.0", only: [:dev, :test]}
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
      nest_modules_by_prefix: [OpenApify.Spec]
    ]
  end

  def doc_extras do
    existing_guides = Path.wildcard("guides/**/*.md")

    defined_guides = [
      "CHANGELOG.md",
      "README.md",
      "guides/quickstart.md"
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
      "Main API": [OpenApify, OpenApify.Controller],
      Plugs: ~r{OpenApify\.Plugs\.},
      Testing: [OpenApify.Test],
      "OpenAPI Spec 3.1": ~r{OpenApify\.Spec\.},
      Parsers: ~r{OpenApify\.Parsers\.},
      "JSON Schema Extensions": ~r{OpenApify\.JsonSchema\.}
    ]
  end

  def cli do
    [
      preferred_envs: [
        dialyzer: :test,
        "oapi.phx.test": :test,
        docs: :doc
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
        {OpenApify.TestWeb, "test/support/test_web", flavor: :phoenix},
        {OpenApify.ConnCase, "test/support/conn_case"},
        {OpenApify, "lib/open_apify"},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task},
        {Plug, "test/support/test_web/plug"},
        {Mix.Tasks.Oapi, :ignore}
      ]
    ]
  end
end
