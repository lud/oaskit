defmodule Oaskit.Validation.ResponseData do
  alias Oaskit.Validation.ResponseValidator

  @moduledoc """
  A subset of a `Plug.Conn` struct representing an HTTP response, used by
  `#{inspect(Oaskit.Test)}` and `#{inspect(ResponseValidator)}`.

  The `:resp_body` key must be parsed if the content-type is `application/json`,
  that is, it must be a map (or other JSON data) and not a binary.
  """

  @enforce_keys [:resp_body, :resp_headers, :status]
  defstruct @enforce_keys

  @type headers :: [{binary, binary}]
  @type t :: %__MODULE__{
          resp_body: term,
          resp_headers: headers,
          status: pos_integer
        }
end
