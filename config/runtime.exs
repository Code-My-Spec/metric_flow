import Config

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
# Load .env files in dev and test via Dotenvy (ADR: dotenvy)
if config_env() in [:dev, :test] do
  Dotenvy.source([".env", ".env.#{config_env()}"])
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
    secret_key_base: secret_key_base

  # Postmark for production email delivery (ADR: email_provider)
  config :metric_flow, MetricFlow.Mailer,
    adapter: Swoosh.Adapters.Postmark,
    api_key: System.fetch_env!("POSTMARK_API_KEY")

  config :swoosh, :api_client, Swoosh.ApiClient.Req

  # Cloak vault key from environment (ADR: deployment)
  if cloak_key = System.get_env("CLOAK_KEY") do
    config :metric_flow, MetricFlow.Vault,
      ciphers: [
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: Base.decode64!(cloak_key), iv_length: 12
        }
      ]
  end

  # Sentry error tracking (ADR: monitoring_observability)
  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: :prod,
    enable_source_code_context: true,
    root_source_code_paths: [File.cwd!()],
    integrations: [
      oban: [capture_errors: true]
    ]

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
         {"0 2 * * *", MetricFlow.DataSync.Scheduler, queue: :sync, max_attempts: 1}
       ]}
    ]
end

# LLM API key — available in all environments for development testing (ADR: llm_provider)
if anthropic_key = System.get_env("ANTHROPIC_API_KEY") do
  config :req_llm, :anthropic_api_key, anthropic_key
end
