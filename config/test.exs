import Config

config :logger, level: :warning

# config :phoenix, :plug_init_mode, :compile
config :phoenix, :plug_init_mode, :runtime

config :jsv,
  resolver_inspect_derive: [only: [:chain, :default_meta]],
  builder_inspect_derive: [only: [:ns, :current_rev_path, :resolver]]
