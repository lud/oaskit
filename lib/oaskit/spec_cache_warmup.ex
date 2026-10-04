defmodule Oaskit.SpecCacheWarmup do
  @moduledoc """
  A child for your supervision tree that builds an OpenAPI specification and
  its validators with `Oaskit.warmup_spec_cache/2`.

  The build happens synchronously when the supervisor starts the child, so the
  application fails at boot if the specification cannot be built. The child
  then returns `:ignore` and the supervisor moves on to the next children.

  Use this when your specification depends on processes started by your
  application, for instance if it loads schemas from the database. Add the
  child after those processes, and before your endpoint so the first requests
  find the specification already built:

      children = [
        MyApp.Repo,
        {Oaskit.SpecCacheWarmup, spec: MyAppWeb.ApiSpec},
        MyAppWeb.Endpoint
      ]

  If your specification reads the runtime configuration of your endpoint, for
  instance with `MyAppWeb.Endpoint.url()`, add the child after the endpoint.
  The endpoint then accepts requests before the specification is built, and
  these requests wait for the build to complete.

  ### Options

  * `:spec` - The spec module to build. Required.
  * `:responses` - See `Oaskit.warmup_spec_cache/2`.
  """

  @doc false
  @spec child_spec(keyword) :: Supervisor.child_spec()
  def child_spec(opts) do
    spec_module = Keyword.fetch!(opts, :spec)

    %{
      id: {__MODULE__, spec_module},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  @doc false
  @spec start_link(keyword) :: :ignore
  def start_link(opts) do
    {spec_module, warmup_opts} = Keyword.pop!(opts, :spec)
    :ok = Oaskit.warmup_spec_cache(spec_module, warmup_opts)
    :ignore
  end
end
