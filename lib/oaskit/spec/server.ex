defmodule Oaskit.Spec.Server do
  use Oaskit.Internal.SpecObject

  # An object representing a server for the API.
  defschema %{
    title: "Server",
    type: :object,
    description: "An object representing a server.",
    properties: %{
      url: %{
        type: :string,
        description: "The URL to the target host. Required. Supports server variables."
      },
      description: %{
        type: :string,
        description: "An optional string describing the host designated by the URL."
      },
      variables: %{
        type: :object,
        additionalProperties: Oaskit.Spec.ServerVariable,
        description:
          "A map between variable names and their values for substitution in the server's URL template."
      }
    },
    required: [:url]
  }

  @impl true
  def normalize!(data, ctx) do
    data
    |> from(__MODULE__, ctx)
    |> normalize_default([:url, :description])
    |> normalize_subs(variables: {:map, Oaskit.Spec.ServerVariable})
    |> collect()
  end

  @doc """
  Returns an URL based on the `:url` configuration of the endpoint.

  If not all the parts of the URL are configured the following defaults are
  used:

  * `:port` defaults to `443`.
  * `:scheme` defaults to `"https"`.
  * `:path` defaults to `"/"`.
  """
  def from_config(otp_app, endpoint_module) when is_atom(otp_app) and is_atom(endpoint_module) do
    with {:ok, config} <- fetch_endpoint_config(otp_app, endpoint_module),
         {:ok, url} <- fetch_required(config, :url),
         {:ok, host} <- fetch_required(url, :host) do
      port = Keyword.get(url, :port, 443)
      scheme = Keyword.get(url, :scheme, "https")
      path = Keyword.get(url, :path, "/")

      uri = %URI{scheme: scheme, host: host, port: port, path: path}

      %__MODULE__{url: to_string(uri)}
    else
      {:error, reason} ->
        raise ArgumentError,
              "could not build url from endpoint #{inspect(endpoint_module)} configuration: #{inspect(reason)}"
    end
  end

  # Fetches a required value from a Keyword list, returning {:ok, value}
  # or {:error, reason} for explicit error handling in `with` statements.
  defp fetch_required(keyword, key) do
    case Keyword.fetch(keyword, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_key, key}}
    end
  end

  defp fetch_endpoint_config(otp_app, module) do
    case Application.fetch_env(otp_app, module) do
      {:ok, _} = ok -> ok
      :error -> {:error, {:no_config, module}}
    end
  end
end
