defmodule OpenApify.TestWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :open_apify

  # This is only there so Firefox will be happy with a favicon and stop
  # generating errors in the logs when testing.
  plug Plug.Static, at: "/", from: "test/support/test_web/assets", only: ~w(favicon.ico)

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, :test],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug OpenApify.TestWeb.Router
end
