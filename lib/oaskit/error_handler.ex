defmodule Oaskit.ErrorHandler do
  alias Oaskit.Errors.InvalidBodyError
  alias Oaskit.Errors.InvalidParameterError
  alias Oaskit.Errors.MissingParameterError
  alias Oaskit.Errors.UnsupportedMediaTypeError
  alias Oaskit.Plugs.ValidateRequest

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
  response and halt the conn with `Plug.Conn.halt/1`.

  Responses can be sent just as in Phoenix controllers, using
  `Plug.Conn.send_resp/3`, `Phoenix.Controller.json/2`,
  `Phoenix.Controller.text/2`, _etc._

  The `#{inspect(ValidateRequest)}` plug returns the conn from this function as
  is. Halting stops the plug pipeline, so the controller action is skipped. A
  conn that is sent but not halted reaches the action, which then fails with
  `Plug.Conn.AlreadySentError` when it tries to send its own response.

      def handle_error(conn, reason, _opts) do
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(422, encode_errors(reason))
        |> Plug.Conn.halt()
      end

  The `arg` argument is the options given to `#{inspect(ValidateRequest)}`. See
  this module documentation for more information.
  """
  @callback handle_error(Plug.Conn.t(), reason, arg :: term) :: Plug.Conn.t()
end
