defmodule Oaskit.Validation.RequestData do
  alias Oaskit.Plugs.ValidateRequest
  alias Oaskit.Validation.RequestValidator

  @moduledoc """
  A subset of a parsed and fetched `Plug.Conn` struct representing an HTTP
  request, used by `#{inspect(ValidateRequest)}` and
  `#{inspect(RequestValidator)}`.
  """

  @enforce_keys [:path_params, :query_params, :body_params, :req_headers]
  defstruct @enforce_keys

  @type headers :: [{binary, binary}]
  @type t :: %__MODULE__{
          path_params: %{optional(binary) => term},
          query_params: %{optional(binary) => term},
          body_params: %{optional(binary) => term},
          req_headers: headers
        }

  @spec from_conn(Plug.Conn.t()) :: t
  def from_conn(%Plug.Conn{} = conn) do
    %{
      path_params: path_params,
      query_params: query_params,
      body_params: body_params,
      req_headers: req_headers
    } = conn

    %__MODULE__{
      path_params: path_params,
      query_params: query_params,
      body_params: body_params,
      req_headers: req_headers
    }
  end
end
