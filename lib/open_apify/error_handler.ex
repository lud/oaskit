defmodule OpenApify.ErrorHandler do
  alias OpenApify.Errors.InvalidBodyError
  alias OpenApify.Errors.InvalidParameterError
  alias OpenApify.Errors.MissingParameterError
  alias OpenApify.Errors.UnsupportedMediaTypeError
  alias OpenApify.Plugs.ValidateRequest

  @moduledoc """
  A behaviour for validation errors handlers.
  """

  @type reason ::
          InvalidBodyError.t()
          | UnsupportedMediaTypeError.t()
          | {:parameters_errors, [InvalidParameterError.t() | MissingParameterError.t()]}

  @doc """
  Accepts the Plug.Conn struct, an error reason and the options passed to the
  `#{inspect(ValidateRequest)}` plug.

  This function is called when request validation fails and an error must be
  returned to the remote client. This means that function _must_ send a
  response.

  Responses can be sent just as in Phoenix controllers, using
  `Plug.Conn.send_resp/3`, `Phoenix.Controller.json/2`,
  `Phoenix.Controller.text/2`, _etc._

  The `arg` argument is the options given to `#{inspect(ValidateRequest)}`. See
  this module documentation for more information.
  """
  @callback handle_error(Plug.Conn.t(), reason, arg :: term) :: Plug.Conn.t()
end
