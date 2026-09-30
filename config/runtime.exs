import Config
import Dotenvy

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/metric_flow start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.

# === Secret loading ==========================================================
#
# Dev/test: source secrets from local .env files (gitignored).
# Prod (UAT + prod box): rel/overlays/bin/boot decrypts envs/<APP_ENV>.enc.env
#   with SOPS_AGE_KEY and execs the release with those values already in
#   the OS environment.
if config_env() in [:dev, :test] do
  env_dir_prefix = System.get_env("RELEASE_ROOT") || "."

  source!([
    Path.absname(".env", env_dir_prefix),
    Path.absname(".env.#{config_env()}", env_dir_prefix),
    System.get_env()
  ])
else
  source!([System.get_env()])
end

# Cloudflare Tunnel — merge secret from env var (dev only)
tunnel_config = Application.get_env(:metric_flow, :cloudflare_tunnel, [])

if tunnel_config[:mode] == :named do
  config :metric_flow, :cloudflare_tunnel,
    Keyword.put(tunnel_config, :tunnel_secret, env!("CLOUDFLARE_TUNNEL_SECRET", :string, ""))
end

# CodeMySpec preview tunnel — reads this checkout's .cms_harness.json (main
# working copy only; every other worktree gets an empty config, which leaves
# the tunnel disabled) so the CodeMySpec preview pane can reach this app.
config :metric_flow,
  :preview,
  ClientUtils.Harness.Preview.config(File.cwd!(),
    origin_url: "http://127.0.0.1:#{System.get_env("PORT", "4070")}"
  )

# Cassette-replay tests validate request parameters (e.g. ReqLLM rejects a nil
# api_key) before a plug ever gets to replay the recording, so :test needs a
# non-nil value even with no .env files present. Real values from .env.test
# still win — this is only the fallback when the key is entirely absent.
test_placeholder = fn value -> if config_env() == :test, do: value end

# OAuth provider credentials — available in all environments
config :metric_flow,
  github_client_id: env!("GITHUB_CLIENT_ID", :string, test_placeholder.("test-github-client-id")),
  github_client_secret: env!("GITHUB_CLIENT_SECRET", :string, test_placeholder.("test-github-client-secret")),
  google_client_id: env!("GOOGLE_CLIENT_ID", :string, test_placeholder.("test-google-client-id.apps.googleusercontent.com")),
  google_client_secret: env!("GOOGLE_CLIENT_SECRET", :string, test_placeholder.("test-google-client-secret")),
  google_ads_developer_token: env!("GOOGLE_ADS_DEVELOPER_TOKEN", :string, test_placeholder.("test-google-ads-developer-token")),
  google_ads_login_customer_id: env!("GOOGLE_ADS_LOGIN_CUSTOMER_ID", :string, test_placeholder.("1234567890")),
  quickbooks_client_id: env!("QUICKBOOKS_CLIENT_ID", :string, test_placeholder.("test-quickbooks-client-id")),
  quickbooks_client_secret: env!("QUICKBOOKS_CLIENT_SECRET", :string, test_placeholder.("test-quickbooks-client-secret")),
  facebook_app_id: env!("FACEBOOK_APP_ID", :string, test_placeholder.("test-facebook-app-id")),
  facebook_app_secret: env!("FACEBOOK_APP_SECRET", :string, test_placeholder.("test-facebook-app-secret")),
  # The recorded cassette used the production host, not sandbox, so :test
  # must default to match — ReqCassette matches full URI including host.
  quickbooks_api_url:
    env!(
      "QUICKBOOKS_API_URL",
      :string,
      test_placeholder.("https://quickbooks.api.intuit.com/v3/company") ||
        "https://sandbox-quickbooks.api.intuit.com/v3/company"
    ),
  codemyspec_url: env!("CODEMYSPEC_URL", :string, "https://app.codemyspec.com"),
  codemyspec_client_id: env!("CODEMYSPEC_CLIENT_ID", :string, nil),
  codemyspec_client_secret: env!("CODEMYSPEC_CLIENT_SECRET", :string, nil),
  codemyspec_project_id: env!("CODEMYSPEC_PROJECT_ID", :string, nil),
  stripe_secret_key: env!("STRIPE_SECRET_KEY", :string, nil),
  stripe_publishable_key: env!("STRIPE_PUBLISHABLE_KEY", :string, nil),
  stripe_webhook_secret: env!("STRIPE_WEBHOOK_SECRET", :string, nil),
  # Connect events (from agencies' connected accounts) arrive through a
  # separate Stripe Connect endpoint with its own shared secret — Stripe
  # does not support a secret per connected account.
  stripe_connect_webhook_secret: env!("STRIPE_CONNECT_WEBHOOK_SECRET", :string, nil)

# Test-only: expose cassette recording credentials via Application config
# so test fixtures can read them without relying on System.get_env.
if config_env() == :test do
  # These four IDs are baked into the recorded cassette request URIs
  # (test/cassettes/data_sync/*.json) — ReqCassette matches on
  # [:method, :uri], so a value that isn't one of these fails to replay
  # even though no real network call is made. A real .env.test value
  # still wins when re-recording against a different test account.
  config :metric_flow, :test_credentials,
    google_ads_customer_id: env!("GOOGLE_ADS_TEST_CUSTOMER_ID", :string, "8952788948"),
    ga4_property_id: env!("GA4_TEST_PROPERTY_ID", :string, "properties/508773792"),
    facebook_ad_account_id: env!("FACEBOOK_TEST_AD_ACCOUNT_ID", :string, "act_135910517"),
    quickbooks_realm_id: env!("QUICKBOOKS_TEST_REALM_ID", :string, "9130355098863166"),
    quickbooks_income_account_id: env!("QUICKBOOKS_TEST_INCOME_ACCOUNT_ID", :string, nil),
    quickbooks_access_token: env!("QUICKBOOKS_TEST_ACCESS_TOKEN", :string, nil),
    google_access_token: env!("GOOGLE_TEST_ACCESS_TOKEN", :string, nil),
    google_refresh_token: env!("GOOGLE_TEST_REFRESH_TOKEN", :string, nil),
    google_ads_login_customer_id: env!("GOOGLE_ADS_LOGIN_CUSTOMER_ID", :string, nil),
    facebook_access_token: env!("FACEBOOK_TEST_ACCESS_TOKEN", :string, nil),
    # Google Business Profile needs both: accounts are what the credential can
    # see, locations are what the user picked out of them, and
    # `GoogleBusiness.resolve_locations/1` reads the second.
    google_business_account_ids: env!("GOOGLE_BUSINESS_TEST_ACCOUNT_IDS", :string, nil),
    google_business_location_ids: env!("GOOGLE_BUSINESS_TEST_LOCATION_IDS", :string, nil)
end

if System.get_env("PHX_SERVER") do
  config :metric_flow, MetricFlowWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :metric_flow, MetricFlow.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :metric_flow, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :metric_flow, MetricFlowWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    check_origin: true,
    secret_key_base: secret_key_base

  # Resend for production email delivery (ADR: email_provider)
  config :metric_flow, MetricFlow.Mailer,
    adapter: Swoosh.Adapters.Resend,
    api_key: env!("RESEND_API_KEY", :string!)

  config :swoosh, :api_client, Swoosh.ApiClient.Req

  # Cloak vault key from environment (ADR: deployment)
  if cloak_key = env!("CLOAK_KEY", :string, nil) do
    config :metric_flow, MetricFlow.Vault,
      ciphers: [
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: Base.decode64!(cloak_key), iv_length: 12
        }
      ]
  end

  # Tigris file storage (ADR: file_storage)
  config :ex_aws,
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")

  config :ex_aws, :s3,
    scheme: "https://",
    host: "fly.storage.tigris.dev",
    region: "auto"

  # Oban cron scheduling in production (ADR: background_job_processing)
  config :metric_flow, Oban,
    plugins: [
      {Oban.Plugins.Pruner, max_age: 604_800},
      {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
      {Oban.Plugins.Cron,
       crontab: [
         {"0 2 * * *", MetricFlow.DataSync.Scheduler, queue: :sync, max_attempts: 1},
         {"30 2 * * *", MetricFlow.Correlations.Scheduler, queue: :correlations, max_attempts: 1}
       ]}
    ]
end

# LLM API key — available in all environments (ADR: llm_provider)
if anthropic_key = env!("ANTHROPIC_API_KEY", :string, test_placeholder.("test-anthropic-api-key")) do
  config :req_llm, :anthropic_api_key, anthropic_key
end

# The support widget's socket, and the key it authenticates with. Read at
# runtime so one image serves every environment.
config :metric_flow,
  codemyspec_widget_url:
    System.get_env("CODEMYSPEC_WIDGET_URL") || "wss://codemyspec.com/widget"

config :metric_flow, :deploy_key, System.get_env("DEPLOY_KEY")
