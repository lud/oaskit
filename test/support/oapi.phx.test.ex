defmodule Mix.Tasks.Oapi.Phx.Test do
  use Mix.Task

  @moduledoc false

  @requirements ["app.config", "compile"]

  @impl true
  def run(_) do
    Application.put_env(:phoenix, :serve_endpoints, true, persistent: true)
    {:ok, _} = Application.ensure_all_started(:oaskit)

    spawn(fn ->
      {:ok, _} = Oaskit.TestWeb.Endpoint.start_link()
      Process.sleep(:infinity)
    end)

    IO.puts("""
    test with:
    * http://localhost:5001/generated/params/some-slug/s/bad-shape/t/bad-theme/c/bad-color?color=not+an+int
    * http://localhost:5001/generated/body/manual-form-show
    * http://localhost:5001/generated/openapi.json
    """)

    Mix.Tasks.Run.run(["--no-halt"])
  end
end
