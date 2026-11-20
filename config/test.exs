import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# CMS_E2E turns this env into a real, listening server so a demo recording
# (journey 66a06609) can drive an actual browser against it. The repo stays
# sandboxed; see the sql_sandbox config below for how a real browser's
# requests still see that transaction.
e2e? = System.get_env("CMS_E2E") in ~w(1 true)

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
#
# Each checkout gets its own test database: the workflow loop runs several
# work copies side by side, and suites sharing one database block on each
# other's uncommitted rows (seeds_test timed out that way).
config :metric_flow, MetricFlow.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database:
    "metric_flow_test_#{:erlang.phash2(Path.expand("..", __DIR__))}#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :metric_flow, MetricFlowWeb.Endpoint,
  http: [
    ip: {127, 0, 0, 1},
    # Deliberately not 4002, so an e2e server and an ordinary `mix test` can't
    # collide on the port.
    port:
      if(e2e?,
        do: String.to_integer(System.get_env("CMS_E2E_PORT") || "4102"),
        else: 4002
      )
  ],
  secret_key_base: "m8YRvmIEM5DxsJnx7oxc4rhAvYmPX8FGq7Wr57xE7JXKKslzrgej720Y6N0iAmTO",
  server: e2e?

# In test we don't send emails
config :metric_flow, MetricFlow.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Keep paywall tests and spex exercising the real gate; override per-test if needed.
config :metric_flow, :paywall_enabled, true

# Oban testing mode — jobs are not executed, but can be asserted on.
# The repo must be set explicitly here because this config replaces the
# base config.exs Oban config entirely in the test environment.
config :metric_flow, Oban,
  repo: MetricFlow.Repo,
  testing: :manual

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
  :stub_authorize_error,
  :stub_revoke,
  :stub_revoke_fail,
  :stub_no_revoke,
  :stub_refreshable,
  :stub_no_refresh,
  :stub_refresh_fail,
  :stub_refresh_raises
]

# Static copy of Google's OIDC discovery document so OAuth URL building in tests
# never calls accounts.google.com.
config :metric_flow, :google_openid_configuration, %{
  "issuer" => "https://accounts.google.com",
  "authorization_endpoint" => "https://accounts.google.com/o/oauth2/v2/auth",
  "token_endpoint" => "https://oauth2.googleapis.com/token",
  "userinfo_endpoint" => "https://openidconnect.googleapis.com/v1/userinfo",
  "jwks_uri" => "https://www.googleapis.com/oauth2/v3/certs",
  "revocation_endpoint" => "https://oauth2.googleapis.com/revoke"
}

# A real Chromium hits the endpoint over actual HTTP, outside any test
# process; this is the documented way it still sees a test's own data
# (https://hexdocs.pm/phoenix_ecto/Phoenix.Ecto.SQL.Sandbox.html) — the
# plug lives in endpoint.ex, the LiveView allow-hook in live_acceptance.ex.
config :metric_flow, :sql_sandbox, true

# phoenix_test_playwright drives a real Chromium against the endpoint above.
# Video recording only when a demo asks for one (CMS_JOURNEY_VIDEO_DIR unset
# otherwise) — mirrors CodeMySpecWeb's own config/test.exs.
config :phoenix_test, otp_app: :metric_flow, endpoint: MetricFlowWeb.Endpoint

config :phoenix_test,
  # The library's own default per-action timeout (2s) is too short for a
  # cold first page load under CMS_E2E -- asset compile plus the LiveView
  # connect pushed it past 2s and flaked the recorder 2 of 3 runs.
  playwright:
    [
      # The first Chromium launch on a cold machine takes longer than the 4s
      # default.
      browser_launch_timeout: 30_000,
      browser: :chromium,
      browser_context_opts:
        if(dir = System.get_env("CMS_JOURNEY_VIDEO_DIR"),
          do: [record_video: %{dir: dir}],
          else: []
        )
    ] ++
      if(e2e?, do: [timeout: 10_000], else: [])
