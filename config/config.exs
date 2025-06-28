import Config

config :open_apify, OpenApify.TestWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  url: [host: "localhost", port: 5001, scheme: "http"],
  debug_errors: true,
  code_reloader: false,
  secret_key_base: "zANuLKxVwY9Tu3MD+g2XBbCWHbkf1G2GSVgiF4NAq9t03UZU/Wbib2/8lpNPLiCh",
  adapter: Bandit.PhoenixAdapter

if config_env() in [:test] do
  import_config "#{config_env()}.exs"
end
