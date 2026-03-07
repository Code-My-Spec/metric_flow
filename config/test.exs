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

# Oban testing mode — jobs are not executed, but can be asserted on.
# The repo must be set explicitly here because this config replaces the
# base config.exs Oban config entirely in the test environment.
config :metric_flow, Oban,
  repo: MetricFlow.Repo,
  testing: :manual

# Disable Sentry in test
config :sentry, dsn: nil

# Default to :warning to reduce noise in test output.
# Tests that need capture_log at :info can use @tag capture_log: true
# with Logger.configure(level: :info) in their setup block.
config :logger, level: :warning

# Silence Phoenix request logs in tests
config :phoenix, :logger, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Allow stub providers in Integration schema during tests
config :metric_flow, :test_providers, [
  :stub,
  :stub_no_expiry,
  :stub_comma_scope,
  :stub_array_scope,
  :stub_token_error,
  :stub_norm_error,
  :stub_callback_error,
  :stub_authorize_error
]

# Provide a placeholder Anthropic API key for tests so ReqLLM does not
# reject the key before ReqCassette can intercept the HTTP request.
# All LLM calls in tests must go through cassette playback (req_http_options: [plug: plug]).
config :req_llm, :anthropic_api_key, "REDACTED_API_KEY"
