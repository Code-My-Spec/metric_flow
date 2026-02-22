import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :metric_flow, MetricFlow.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "metric_flow_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :metric_flow, MetricFlowWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "m8YRvmIEM5DxsJnx7oxc4rhAvYmPX8FGq7Wr57xE7JXKKslzrgej720Y6N0iAmTO",
  server: false

# In test we don't send emails
config :metric_flow, MetricFlow.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Oban testing mode — jobs are not executed, but can be asserted on
config :metric_flow, Oban, testing: :manual

# Disable Sentry in test
config :sentry, dsn: nil

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
