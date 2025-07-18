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

  ## Showing Redoc

  Redoc is a simple documentation generator that will display an OpenAPI
  specification in a nice way. It does not allow to test the routes though.

  Pass the absolute URL path to the controller with the `:redoc` option, and
  optionally a redoc configuration object:

      get "/redoc", Oaskit.SpecController, redoc: "/url/to/openapi.json"
      get "/redoc", Oaskit.SpecController,
        redoc: "/generated/openapi.json",
        redoc_config: %{
          "minCharacterLengthToInitSearch" => 1,
          "hideDownloadButtons" => true
        }

  ## Other options

  A `:resp_headers` option can be provided to set the response headers for the
  JSON or Redoc routes.

      pipeline :api do
        get "/openapi.json", Oaskit.SpecController,
          spec: MyApp.ApiSpec,
          resp_headers: %{"access-control-allow-origin" => "*"}
      end

  """

  def init(opts) do
    case opts do
      :show -> %{action: :serve_spec, spec: :__provided__}
      list when is_list(list) -> init(Map.new(list))
      %{spec: true} -> Map.merge(opts, %{action: :serve_spec, spec: :__provided__})
      %{spec: module} -> Map.merge(opts, %{action: :serve_spec, spec: module})
      %{redoc: path} -> Map.merge(opts, %{action: :redoc, path: path})
    end
  end

  def call(conn, opts) do
    case opts do
      %{action: :serve_spec} -> serve_spec(conn, opts)
      %{action: :redoc} -> serve_redoc(conn, opts)
    end
  end

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
      <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"></script>
      <script>
      Redoc.init(<%= path %>,<%= config %>,document.getElementById("redoc-root"))
      </script>
    </body>
  </html>
  """

  EEx.function_from_string(:defp, :redoc_ui, @redoc_ui, [:path, :config])

  # sobelow_skip ["XSS.SendResp"]
  defp serve_redoc(conn, params) do
    path = Codec.encode!(params.path)
    config = Codec.encode!(Map.get(params, :redoc_config, %{}))
    html = redoc_ui(path, config)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end
end
