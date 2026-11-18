# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :metric_flow, :scopes,
  user: [
    default: true,
    module: MetricFlow.Users.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: MetricFlow.UsersFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :metric_flow,
  ecto_repos: [MetricFlow.Repo],
  generators: [timestamp_type: :utc_datetime]

# Story 74: versions the dashboard A2UI blob (restore creates a new version)
config :paper_trail, repo: MetricFlow.Repo

# Gates every paywall/subscription check in the app. Overridden to false
# in dev so gated features are usable without a subscription.
config :metric_flow, :paywall_enabled, true

# Configures the endpoint
config :metric_flow, MetricFlowWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MetricFlowWeb.ErrorHTML, json: MetricFlowWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MetricFlow.PubSub,
  live_view: [signing_salt: "rqGwPWkm"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :metric_flow, MetricFlow.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  metric_flow: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  metric_flow: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id]

# Spans are created everywhere but only exported where config/runtime.exs
# finds OTEL_EXPORTER_OTLP_ENDPOINT (the UAT box's OTel collector).
config :opentelemetry, traces_exporter: :none

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Cloak encryption vault configuration
config :metric_flow, MetricFlow.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("w09FSTq2MKlGVsfejph/sQiw6j9PSrqmgpCccRNG33s="),
      iv_length: 12
    }
  ]

# OAuth authorization server for MCP clients (Claude, ChatGPT, ...). Only the
# authorization-code grant (PKCE S256 enforced in OAuthController) and refresh.
config :metric_flow, ExOauth2Provider,
  repo: MetricFlow.Repo,
  resource_owner: MetricFlow.Users.User,
  access_token: MetricFlow.Oauth.AccessToken,
  application: MetricFlow.Oauth.Application,
  access_grant: MetricFlow.Oauth.AccessGrant,
  grant_flows: ~w(authorization_code),
  use_refresh_token: true,
  access_token_expires_in: 7200,
  # Redirect URIs are checked per client (HTTPS, or http on localhost).
  force_ssl_in_redirect_uri: false

# Oban job processing (ADR: background_job_processing)
config :metric_flow, Oban,
  repo: MetricFlow.Repo,
  queues: [default: 10, sync: 5, correlations: 3],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 604_800},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ]

# ExAws for Tigris file storage (ADR: file_storage)
# Use Req as the HTTP adapter to avoid adding Hackney as a dependency
config :ex_aws,
  json_codec: Jason,
  http_client: ExAws.Request.Req

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
