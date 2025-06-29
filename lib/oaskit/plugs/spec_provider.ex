defmodule Oaskit.Plugs.SpecProvider do
  alias Oaskit.Plugs.ValidateRequest

  @moduledoc """
  A plug to associate an OpenAPI specification with a group of routes in a
  router or a controller.

  It takes a `:spec` option with the name of a module implementing the
  `Oaskit` behaviour.

  It will generally be used from a `Phoenix.Router` implementation:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        # The provider should be called in a pipeline.
        pipeline :api do
          plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.ApiSpec
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
    Plug.Conn.put_private(conn, :oaskit, %{spec: module})
  end

  @doc """
  Returns the spec module from a conn if the conn went through this plug, raises
  an error otherwise.
  """
  def fetch_spec_module!(conn) do
    case conn do
      %{private: %{oaskit: %{spec: module}}} ->
        module

      _ ->
        raise """
        cannot fetch spec module, missing  #{inspect(Oaskit.Plugs.SpecProvider)} plug in pipeline

        Make sure to provide a spec module:

        1. First define a pipeline with the provider plug:

            pipeline :api do
              plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.OpenAPISpec
            end

        2. Use the validation plug or spec controller in a scope using that pipeline:

            scope "/api", MyAppWeb.Api do
              pipe_through :api

              get "/hello", HelloController, :hello
            end
        """
    end
  end
end
