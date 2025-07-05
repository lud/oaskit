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
    with {:ok, config} <- Application.fetch_env(otp_app, endpoint_module),
         {:ok, url} <- Keyword.fetch(config, :url),
         {:ok, host} <- Keyword.fetch(url, :host) do
      port = Keyword.get(url, :port, 443)
      scheme = Keyword.get(url, :scheme, "https")
      path = Keyword.get(url, :path, "/")

      url =
        %URI{scheme: scheme, host: host, port: port, path: path}

      %__MODULE__{url: to_string(url)}
    else
      e -> raise ArgumentError, "could not build url from configuration: #{inspect(e)}"
    end
  end
end
