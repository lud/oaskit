defmodule Oaskit.SpecController do
  alias JSV.Codec
  alias Oaskit.Plugs.SpecProvider
  import Plug.Conn
  require EEx

  @behaviour Plug

  @moduledoc """
  Controller for serving OpenAPI specifications in JSON format or Redoc UI.

  ## Serving the JSON spec

  Add a route in your router by passing the spec module to this controller:

      get "/openapi.json", Oaskit.SpecController, spec: MyAppWeb.ApiSpec

  Alternatively, you can automatically serve the spec that provided with the
  spec provider plug by giving the `spec: true` option or by replacing the
  options with `:show`. The route needs to be scoped with the appropriate
  pipeline:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        pipeline :api do
          plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.ApiSpec
        end

        scope "/" do
          pipe_through :api

          get "/openapi.json", Oaskit.SpecController, :show
          # OR
          get "/openapi.json", Oaskit.SpecController, spec: true
        end
      end

  This will serve your OpenAPI specification at `/openapi.json`. Add `?pretty=1`
  in the URL for easier debugging.

  The controller works with any spec module that implements the `Oaskit`
  behavior. Note that if your spec is obtained from a static file, you don't
  really need that controller and can just serve that file.

  ## Showing Redoc 3

  [Redoc](https://redocly.com/docs/redoc) renders an OpenAPI specification as a
  browsable documentation website, with request and response schemas, examples
  and search.

  Pass the absolute URL path of your JSON spec route with the `:redoc3` option:

      get "/openapi.json", Oaskit.SpecController, spec: MyAppWeb.ApiSpec
      get "/docs", Oaskit.SpecController, redoc3: "/openapi.json"

  The `:redoc_config` option takes a map of [Redoc 3
  options](https://redocly.com/docs/redoc/v3.x/config), given to Redoc as is:

      get "/docs", Oaskit.SpecController,
        redoc3: "/openapi.json",
        redoc_config: %{
          "layout" => "stacked",
          "hideDownloadButtons" => true
        }

  The controller sets `"disableTelemetry" => true` in the Redoc options, which
  turns off the [usage telemetry](https://redocly.com/docs/redoc/telemetry) that
  Redoc 3 sends to Redocly. Define `"disableTelemetry"` in `:redoc_config` to
  choose the value yourself.

  The page loads a bundle pinned to an exact Redoc version from
  `https://cdn.redoc.ly`, checked with Subresource Integrity, and starts Redoc
  from an inline module script. If your application sets a Content Security
  Policy on this route, allow that origin and `'unsafe-inline'` in `script-src`.

  ## Showing Redoc 2

  The `:redoc` option serves Redoc 2. It accepts the `:redoc_config` option as
  well, with [Redoc 2 options](https://redocly.com/docs/redoc/v2.x/config):

      get "/docs", Oaskit.SpecController,
        redoc: "/openapi.json",
        redoc_config: %{
          "expandResponses" => "200,201",
          "hideDownloadButton" => true
        }

  To switch a route from `:redoc` to `:redoc3`, update its `:redoc_config`
  following the [Redoc 3 migration
  guide](https://redocly.com/docs/redoc/v3.x/config-migration).

  ## Other options

  A `:resp_headers` option can be provided to set the response headers for the
  JSON spec route.

      get "/openapi.json", Oaskit.SpecController,
        spec: MyApp.ApiSpec,
        resp_headers: %{"access-control-allow-origin" => "*"}

  """

  def init(opts) do
    case opts do
      :show -> %{action: :serve_spec, spec: :__provided__}
      list when is_list(list) -> init(Map.new(list))
      %{spec: true} -> Map.merge(opts, %{action: :serve_spec, spec: :__provided__})
      %{spec: module} -> Map.merge(opts, %{action: :serve_spec, spec: module})
      %{redoc: path} -> Map.merge(opts, %{action: :redoc, path: path})
      %{redoc3: path} -> Map.merge(opts, %{action: :redoc3, path: path})
    end
  end

  def call(conn, opts) do
    case opts do
      %{action: :serve_spec} -> serve_spec(conn, opts)
      %{action: :redoc} -> serve_redoc(conn, opts)
      %{action: :redoc3} -> serve_redoc3(conn, opts)
    end
  end

  @doc false
  def serve_spec(conn, opts) do
    conn = fetch_query_params(conn)
    module = fetch_spec!(conn, opts)
    _ = Code.ensure_loaded(module)

    case function_exported?(module, :spec, 0) do
      true -> do_serve_spec(conn, module, opts)
      false -> send_resp(conn, 500, "Undefined OpenAPI Specification #{inspect(module)}.spec()")
    end
  end

  defp do_serve_spec(conn, module, opts) do
    json = Oaskit.to_json!(module, pretty: pretty?(conn.query_params))

    conn
    |> put_resp_content_type("application/json")
    |> maybe_put_resp_headers(opts)
    |> send_resp(200, json)
  end

  defp maybe_put_resp_headers(conn, %{resp_headers: headers})
       when is_map(headers)
       when is_list(headers) do
    Enum.reduce(headers, conn, fn {k, v}, conn -> put_resp_header(conn, k, v) end)
  end

  defp maybe_put_resp_headers(conn, _) do
    conn
  end

  defp fetch_spec!(conn, %{spec: :__provided__}) do
    SpecProvider.fetch_spec_module!(conn)
  end

  defp fetch_spec!(_conn, %{spec: module}) do
    module
  end

  defp pretty?(params) do
    case params do
      %{"pretty" => "true"} -> true
      %{"pretty" => "1"} -> true
      _ -> false
    end
  end

  # Redoc is loaded from the CDN pinned to an exact version and guarded with a
  # Subresource Integrity hash, so a compromised or swapped CDN bundle cannot
  # execute in the browser. Both pins are maintained by ./tools/update-redoc.exs
  @redoc_version "2.5.4"
  @redoc_sri "sha384-w447zOpYfw/1Tv/5AK9NfHTlQIqE3RVR6KY62jCyy9zNDgO64cMwGGP1Fj0zJVf5"
  @redoc_src "https://cdn.redoc.ly/redoc/v#{@redoc_version}/bundles/redoc.standalone.js"

  @redoc3_version "3.0.1"
  @redoc3_sri "sha384-j07qRKHNNmcwU1/Y1elJc7pDLHXP/QfbQXTtSkbOJ7uYGJikqAzsFVbY2zR9FqOT"
  @redoc3_src "https://cdn.redoc.ly/redoc/v#{@redoc3_version}/bundles/redoc.standalone.js"

  @redoc_ui """
  <!DOCTYPE html>
  <html>
    <head>
      <title>Redoc</title>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>body {margin: 0;padding: 0;}</style>
    </head>
    <body>
      <div id="redoc-root"></div>
      <script src="#{@redoc_src}" integrity="#{@redoc_sri}" crossorigin="anonymous"></script>
      <script>
      Redoc.init(<%= path %>,<%= config %>,document.getElementById("redoc-root"))
      </script>
    </body>
  </html>
  """

  EEx.function_from_string(:defp, :redoc_ui, @redoc_ui, [:path, :config])

  # The v3 bundle is an ES module. The import map integrity entry and the
  # modulepreload link both bind the SRI hash to the URL that the inline module
  # imports.
  @redoc3_ui """
  <!DOCTYPE html>
  <html>
    <head>
      <title>Redoc</title>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>body {margin: 0;padding: 0;}</style>
      <script type="importmap">{"integrity":{"#{@redoc3_src}":"#{@redoc3_sri}"}}</script>
      <link rel="modulepreload" href="#{@redoc3_src}" integrity="#{@redoc3_sri}" crossorigin="anonymous">
    </head>
    <body>
      <div id="redoc-root"></div>
      <script type="module">
      import {init} from "#{@redoc3_src}"
      init(<%= path %>,<%= config %>,document.getElementById("redoc-root"))
      </script>
    </body>
  </html>
  """

  EEx.function_from_string(:defp, :redoc3_ui, @redoc3_ui, [:path, :config])

  # sobelow_skip ["XSS.SendResp"]
  defp serve_redoc(conn, params) do
    path = encode_for_script(params.path)
    config = encode_for_script(Map.get(params, :redoc_config, %{}))
    html = redoc_ui(path, config)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  # sobelow_skip ["XSS.SendResp"]
  defp serve_redoc3(conn, params) do
    path = encode_for_script(params.path)

    config =
      params
      |> Map.get(:redoc_config, %{})
      |> disable_telemetry_by_default()
      |> encode_for_script()

    html = redoc3_ui(path, config)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp disable_telemetry_by_default(config) do
    case config do
      %{"disableTelemetry" => _} -> config
      %{disableTelemetry: _} -> config
      _ -> Map.put(config, "disableTelemetry", true)
    end
  end

  # A "<" can only appear in JSON strings, where "\u003c" is equivalent, so
  # "</script>" cannot close the inline script.
  defp encode_for_script(data) do
    data
    |> Codec.encode!()
    |> String.replace("<", "\\u003c")
  end
end
