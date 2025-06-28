defmodule OpenApify.Plugs.SpecProvider do
  alias OpenApify.Plugs.ValidateRequest

  @moduledoc """
  A plug to associate an OpenAPI specification with a group of routes in a
  router or a controller.

  It takes a `:spec` option with the name of a module implementing the
  `OpenApify` behaviour.

  It will generally be used from a `Phoenix.Router` implementation:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        # The provider should be called in a pipeline.
        pipeline :api do
          plug OpenApify.Plugs.SpecProvider, spec: MyAppWeb.ApiSpec
        end

        scope "/api", MyAppWeb.Api do
          # Then that pipeline can be used in one or
          # more scopes.
          pipe_through :api

          # Controllers used in such scopes can now use
          # the `#{inspect(ValidateRequest)}` plug.
          get "/hello", HelloController, :hello
        end
      end

  > ### Why do we need this? {: .info}
  >
  > Why not directly pass the spec module to `#{inspect(ValidateRequest)}`?
  >
  > Because we may want to attach a controller action and its operation ID to
  > multiple API specifications.
  >
  > For that reason, specs are attached to routes using a pipeline, and not to
  > controllers. This is why this plug is used in router modules, while the
  > `#{inspect(ValidateRequest)}` plug will take whatever spec was given in the
  > conn and fetch the operation ID from there.
  """

  @behaviour Plug

  def init(opts) do
    Keyword.fetch!(opts, :spec)
  end

  def call(conn, module) do
    Plug.Conn.put_private(conn, :open_apify, %{spec: module})
  end
end
