# Fly.io Deployment: Setup and Operations Guide

This guide covers deploying MetricFlow to Fly.io. It maps directly to the decisions recorded in `docs/architecture/decisions/deployment.md` and provides the concrete steps, configuration, and code required to implement each aspect.

## Prerequisites

Install the Fly CLI before starting:

```bash
brew install flyctl
fly auth login
```

---

## 1. Initial Setup with `fly launch`

Run `fly launch` from the project root. The CLI detects a Phoenix project and handles most scaffolding automatically.

```bash
fly launch
```

What `fly launch` does for a Phoenix project:

- Runs `mix phx.gen.release --docker` internally, generating `Dockerfile`, `.dockerignore`, `rel/env.sh.eex`, and `lib/metric_flow/release.ex`
- Creates a `fly.toml` in the project root
- Offers to provision a Fly Managed Postgres or legacy Fly Postgres app and sets `DATABASE_URL` automatically
- Appends IPv6 environment variables to the generated `rel/env.sh.eex`

Do not accept the default choices blindly. When prompted:

- **Region**: Choose the region closest to the team or expected user base (e.g., `ord` for Chicago, `iad` for Virginia)
- **Postgres**: Accept Managed Postgres (simpler) or decline and provision separately for cost control. See the cost note in the decision record.
- **Deploy now**: Choose No. Inspect the generated files before first deploy.

### Generated `fly.toml` structure

After `fly launch`, `fly.toml` will look roughly like this:

```toml
app = "metric-flow"
primary_region = "iad"

[build]

[deploy]
  release_command = "/app/bin/metric_flow eval MetricFlow.Release.migrate"

[env]
  PHX_HOST = "metricflow.app"
  PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 0

  [http_service.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 800

[[vm]]
  memory = "512mb"
  cpu_kind = "shared"
  cpus = 1
```

Key fields to verify after generation:

- `release_command` must reference `MetricFlow.Release.migrate` — confirm it was generated correctly
- `PHX_HOST` must be set to the production domain, not `example.com`
- `auto_stop_machines = "stop"` will stop idle machines to save cost but introduces cold-start latency; set to `"off"` if you need always-on availability
- The `[[vm]]` section controls machine size — `512mb` is sufficient for early scale

### Generated `Dockerfile`

The generated Dockerfile is a multi-stage build that:

1. Compiles assets with Node/esbuild/Tailwind in a build stage
2. Compiles the Elixir release
3. Produces a minimal runtime image based on Debian Buster

The file should not need manual changes for initial deployment. The key line to verify is that `mix assets.deploy` is called before the release compilation step:

```dockerfile
# Verify this line exists in the build stage:
RUN mix assets.deploy
```

If you later add native dependencies (NIFs), you will need to adjust the base image.

---

## 2. BEAM Clustering Configuration

MetricFlow already depends on `dns_cluster ~> 0.2.0` and `DNSCluster` is started in `MetricFlow.Application`. The remaining setup is all in environment variables.

### Why IPv6 is required

Fly machines communicate over a WireGuard mesh network using IPv6 addresses. Erlang's default distribution protocol (`inet_tcp`) does not support IPv6. The `ERL_AFLAGS` setting switches to `inet6_tcp`, which does.

### `rel/env.sh.eex` — the canonical place for these settings

`fly launch` generates `rel/env.sh.eex` and populates it. After generation, verify it contains all of the following:

```bash
# rel/env.sh.eex

# Use IPv6 for Erlang distribution — required for Fly's WireGuard mesh
export ERL_AFLAGS="-proto_dist inet6_tcp"

# Use the Fly machine's IPv6 address as the node name
export RELEASE_DISTRIBUTION="name"
export RELEASE_NODE="<%= @release.name %>@${FLY_PRIVATE_IP}"

# Tell Ecto to connect over IPv6
export ECTO_IPV6="true"

# Point dns_cluster at Fly's internal DNS for node discovery
export DNS_CLUSTER_QUERY="${FLY_APP_NAME}.internal"
```

`FLY_PRIVATE_IP` and `FLY_APP_NAME` are provided automatically by the Fly runtime environment.

### Verifying the `runtime.exs` connection

`config/runtime.exs` already reads `ECTO_IPV6` and `DNS_CLUSTER_QUERY`:

```elixir
# Already in config/runtime.exs — verify these are present:
maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

config :metric_flow, MetricFlow.Infrastructure.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: maybe_ipv6

config :metric_flow, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
```

### Verifying the application supervisor

`MetricFlow.Application` already starts `DNSCluster` correctly:

```elixir
# lib/metric_flow/application.ex — confirm this line exists:
{DNSCluster, query: Application.get_env(:metric_flow, :dns_cluster_query) || :ignore}
```

When `DNS_CLUSTER_QUERY` is not set (development), `DNSCluster` runs with `:ignore` and clustering is disabled. In production on Fly, it queries `metric-flow.internal` and connects to any other machines in the app.

### Checking cluster membership

To confirm nodes are connected after deploy:

```bash
fly ssh console --app metric-flow
/app/bin/metric_flow remote
# In the IEx shell:
Node.list()
```

---

## 3. Wildcard TLS for Agency White-Label Subdomains

The `Agencies.WhiteLabelConfig` schema stores a `subdomain` per agency. Traffic to `acme.metricflow.app` must reach the application and the app must derive the tenant from the host header. This requires both a wildcard DNS record and a wildcard TLS certificate.

### DNS setup

At your DNS registrar, add:

```
A   metricflow.app          ->  <fly IPv4 IP>
A   *.metricflow.app        ->  <fly IPv4 IP>
AAAA metricflow.app         ->  <fly IPv6 IP>
AAAA *.metricflow.app       ->  <fly IPv6 IP>
```

Get the IP addresses with:

```bash
fly ips list --app metric-flow
```

Alternatively, CNAME the apex to the `.fly.dev` subdomain if your DNS provider supports CNAME flattening (Cloudflare does):

```
CNAME  metricflow.app       metric-flow.fly.dev
CNAME  *.metricflow.app     metric-flow.fly.dev
```

### Issuing the wildcard certificate

Wildcard certificates require a DNS-01 ACME challenge because HTTP-01 challenges cannot validate `*.metricflow.app`. Fly handles the certificate renewal automatically once the DNS challenge record is in place.

```bash
fly certs add "metricflow.app" --app metric-flow
fly certs add "*.metricflow.app" --app metric-flow
```

After running each command, Fly prints the DNS TXT record value needed for DNS-01 validation. Add a `_acme-challenge` TXT record at your DNS provider with that value, then wait for validation (typically 2–10 minutes):

```bash
fly certs check "*.metricflow.app" --app metric-flow
```

When `Status` shows `Ready`, the certificate is issued and automatic renewal is active.

### Application-level subdomain routing

The application must read `conn.host`, identify the subdomain, and look up the corresponding agency. This should be a Plug added early in the browser pipeline.

Create `lib/metric_flow_web/plugs/subdomain_context.ex`:

```elixir
defmodule MetricFlowWeb.Plugs.SubdomainContext do
  @moduledoc """
  Detects agency subdomain from the request host and assigns the
  matching WhiteLabelConfig to conn.assigns[:agency_white_label_config].

  Requests to the root domain (metricflow.app) pass through unmodified.
  Requests to unknown subdomains are passed through without an assignment,
  allowing the LiveView to handle the 404 case.
  """

  import Plug.Conn
  alias MetricFlow.Agencies

  @root_host Application.compile_env(:metric_flow, :root_host, "metricflow.app")

  def init(opts), do: opts

  def call(conn, _opts) do
    case extract_subdomain(conn.host) do
      nil ->
        conn

      subdomain ->
        case Agencies.get_white_label_config_by_subdomain(subdomain) do
          nil -> conn
          config -> assign(conn, :agency_white_label_config, config)
        end
    end
  end

  defp extract_subdomain(host) do
    case String.split(host, ".") do
      [subdomain | rest] when rest != [] ->
        base = Enum.join(rest, ".")
        if base == @root_host, do: subdomain, else: nil

      _ ->
        nil
    end
  end
end
```

Add it to the browser pipeline in `router.ex`:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {MetricFlowWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers, %{...}
  plug :fetch_current_scope_for_user
  plug MetricFlowWeb.Plugs.SubdomainContext   # add this
end
```

### `check_origin` for LiveView WebSocket connections

LiveView WebSocket connections validate the `Origin` header against `check_origin` in the endpoint config. With agency subdomains, connections from `acme.metricflow.app` will fail `check_origin` unless the endpoint is configured to accept them.

The recommended approach is a wildcard pattern in `config/prod.exs`:

```elixir
# config/prod.exs
config :metric_flow, MetricFlowWeb.Endpoint,
  check_origin: [
    "https://metricflow.app",
    "https://*.metricflow.app"
  ]
```

The `*` wildcard in `check_origin` is supported by Phoenix and covers all agency subdomains without enumerating them individually. Do not use `check_origin: false` — this disables cross-site WebSocket hijacking protection entirely.

---

## 4. Zero-Downtime Ecto Migrations

### How `release_commands` works on Fly

The `release_command` in `fly.toml` runs in a temporary, short-lived machine before any new machines are started. It uses the same Docker image as the deploy. Fly does not shift traffic to new machines until the release command exits with status 0. If it exits with a non-zero status, the deploy is aborted and existing machines continue running.

This means migrations run against the live database while the old version of the application is still serving traffic. Every migration must therefore be safe to run while the previous version of the code is running.

### The release module

`fly launch` generates `lib/metric_flow/release.ex`. The generated module should look like:

```elixir
defmodule MetricFlow.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix installed.
  """

  @app :metric_flow

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

Verify this module is present at `lib/metric_flow/release.ex` and that the repo module name matches `MetricFlow.Infrastructure.Repo`.

### `fly.toml` release_command

```toml
[deploy]
  release_command = "/app/bin/metric_flow eval MetricFlow.Release.migrate"
```

### Safe migration patterns for MetricFlow

Because migrations run while the old code is live, avoid locking writes. Rules to follow for each migration file:

**Adding a column:** Always add with a default value or as nullable. The old code running in parallel does not know about the new column and will not set it.

```elixir
# Safe: nullable column
alter table(:sync_jobs) do
  add :retry_count, :integer
end

# Safe: column with database default
alter table(:sync_jobs) do
  add :retry_count, :integer, default: 0, null: false
end
```

**Renaming a column:** Never rename directly. Use the expand/contract pattern: add the new column, deploy code that writes to both, backfill, deploy code that reads from only the new column, drop the old column.

**Adding an index:** Use `create index(..., concurrently: true)` and `@disable_ddl_transaction true` to avoid locking the table during index creation.

```elixir
defmodule MetricFlow.Infrastructure.Repo.Migrations.AddIndexToSyncJobsStatus do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:sync_jobs, [:status], concurrently: true)
  end
end
```

**Adding a NOT NULL constraint:** Never add `NOT NULL` with `alter table` on a populated column. Add as nullable, backfill the column, then add the constraint in a later migration.

**Dropping a column:** Only safe after all running code has stopped referencing it. Always lag by at least one deploy cycle.

### Running migrations manually

For emergency or out-of-band migrations:

```bash
fly ssh console --app metric-flow
/app/bin/metric_flow eval MetricFlow.Release.migrate
```

---

## 5. CI/CD with GitHub Actions

Create `.github/workflows/deploy.yml` in the project root.

```yaml
name: CI and Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  MIX_ENV: test
  ELIXIR_VERSION: "1.15"
  OTP_VERSION: "26"

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: metric_flow_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}

      - name: Restore dependencies cache
        uses: actions/cache@v4
        with:
          path: deps
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-

      - name: Restore build cache
        uses: actions/cache@v4
        with:
          path: _build
          key: ${{ runner.os }}-build-${{ env.MIX_ENV }}-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-build-${{ env.MIX_ENV }}-

      - name: Install dependencies
        run: mix deps.get

      - name: Check formatting
        run: mix format --check-formatted

      - name: Compile (warnings as errors)
        run: mix compile --warnings-as-errors

      - name: Run tests
        run: mix test
        env:
          DATABASE_URL: ecto://postgres:postgres@localhost/metric_flow_test

  deploy:
    name: Deploy to Fly.io
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy
        run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### Setting the `FLY_API_TOKEN` secret

Generate a deploy token (scoped to the app, preferred over the full account token):

```bash
fly tokens create deploy --app metric-flow
```

In the GitHub repository: Settings > Secrets and variables > Actions > New repository secret.

- Name: `FLY_API_TOKEN`
- Value: the token printed by the command above

### Notes on `--remote-only`

`flyctl deploy --remote-only` builds the Docker image on Fly's remote builder machines rather than on the GitHub Actions runner. This avoids needing Docker-in-Docker setup on the runner and significantly reduces build time for large projects. The trade-off is that the first remote build is slower; subsequent builds use layer caching on the remote builder.

### The `client_utils` path dependency

`mix.exs` has `{:client_utils, path: "../client_utils"}`. A path dependency will not resolve in CI. Before the deploy workflow runs reliably, either:

1. Publish `client_utils` to a private Hex registry and reference it by version
2. Include the `client_utils` source in the same repository as a subdirectory and adjust the path
3. Use a Git dependency: `{:client_utils, github: "org/client_utils", ref: "..."}`

The path dependency also causes issues with `fly deploy --remote-only` because the remote builder cannot access local paths.

### The `sexy_spex` path dependency

`mix.exs` has `{:sexy_spex, path: "/Users/johndavenport/Documents/github/spex"}`. This absolute path will fail in CI. The same resolution options apply.

---

## 6. Production Secrets Management

Secrets on Fly.io are stored encrypted and injected as environment variables at machine startup. They are never visible in `fly.toml` or logs.

### Required secrets at first deploy

```bash
# Phoenix secret key base
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret) --app metric-flow

# Database connection — set automatically if you used fly launch with Postgres
# If setting manually:
fly secrets set DATABASE_URL="ecto://user:pass@host/metric_flow_prod" --app metric-flow

# Cloak encryption key for OAuth token fields
# Generate with: :crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()
fly secrets set CLOAK_KEY="your-base64-encoded-32-byte-key" --app metric-flow

# OAuth provider credentials
fly secrets set GITHUB_CLIENT_ID="..." GITHUB_CLIENT_SECRET="..." --app metric-flow
fly secrets set GOOGLE_CLIENT_ID="..." GOOGLE_CLIENT_SECRET="..." --app metric-flow
```

### Moving the Cloak key out of `config.exs`

The Cloak vault key is currently hardcoded in `config/config.exs`:

```elixir
# CURRENT STATE — insecure, must be changed before production deploy
config :metric_flow, MetricFlow.Infrastructure.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("w09FSTq2MKlGVsfejph/sQiw6j9PSrqmgpCccRNG33s="),
      iv_length: 12
    }
  ]
```

This key must be moved to a runtime environment variable before deploying to production. Committing a production vault key to source control would expose all encrypted OAuth access and refresh tokens stored in the `integrations` table.

The correct approach uses the Vault's `init/1` GenServer callback to read from the environment at runtime. Update `lib/metric_flow/infrastructure/vault.ex`:

```elixir
defmodule MetricFlow.Infrastructure.Vault do
  use Cloak.Vault, otp_app: :metric_flow

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers, [
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: Base.decode64!(System.fetch_env!("CLOAK_KEY")),
          iv_length: 12
        }
      ])

    {:ok, config}
  end
end
```

Remove the compile-time Cloak configuration from `config/config.exs` entirely. The `init/1` callback runs at application start after the environment is loaded, so it works correctly in both development (with a local `CLOAK_KEY` env var or `.env` file) and production (with `fly secrets`).

For local development, generate a dev key once and set it in your shell:

```bash
# In your ~/.zshrc or a project .env file (never committed):
export CLOAK_KEY=$(iex -e ':crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts' -e ':init.stop()')
```

### Listing and rotating secrets

```bash
# List secret names (values are never shown)
fly secrets list --app metric-flow

# Rotate the secret key base (invalidates all sessions)
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret) --app metric-flow

# Rotate the Cloak key
# WARNING: rotating CLOAK_KEY makes all existing encrypted data unreadable
# unless you re-encrypt it first. This is a data migration, not just a config change.
# See the Cloak key rotation documentation before proceeding.
```

### OAuth provider credentials

OAuth callback URLs must match what the provider expects. For GitHub and Google, register the production callback URL:

```
https://metricflow.app/integrations/callback/github
https://metricflow.app/integrations/callback/google
```

The callback controller is already at `GET /integrations/callback/:platform` in the router. Update your GitHub OAuth App and Google Cloud Console credential entries to include this production URL.

---

## 7. Oban Multi-Node Considerations

MetricFlow's Oban configuration is in `config/config.exs`:

```elixir
config :metric_flow, Oban,
  repo: MetricFlow.Infrastructure.Repo,
  queues: [default: 10, sync: 5]
```

### Single machine (current recommended state)

At early scale, a single Fly machine is the correct configuration. The `sync` queue handles daily data sync jobs for OAuth integrations (GitHub, Google). With 10–100 accounts this is well within what a single machine can handle.

No additional Oban configuration is needed for single-machine operation.

### Two machines (for availability)

When you scale to two machines for availability (`fly scale count 2`), Oban's behavior changes:

- **Job execution**: Both machines pull from the `default` and `sync` queues. PostgreSQL advisory locks inside Oban ensure a job is executed by exactly one machine. No configuration change is needed.
- **Plugins (Cron, Pruner, etc.)**: Starting with Oban 2.11, a table-based leadership mechanism ensures only one node runs plugins at a time. The `oban_peers` table (created by the Oban migrations) tracks which node is the leader. When the leader exits, other nodes compete to become the new leader. No manual configuration is needed.

This means you can safely scale to two machines and the daily sync scheduler (`Oban.Plugins.Cron`) will fire from only one of them at any given time.

### Verifying Oban migrations were run

Oban requires its own table migrations. These are separate from application migrations and must be installed via Oban's migration module. Check that the `oban_jobs` and `oban_peers` tables exist:

```bash
fly ssh console --app metric-flow
/app/bin/metric_flow remote
# In IEx:
MetricFlow.Infrastructure.Repo.query!("SELECT table_name FROM information_schema.tables WHERE table_name LIKE 'oban%'")
```

If the tables are missing, add the Oban migration to `priv/repo/migrations/`:

```elixir
defmodule MetricFlow.Infrastructure.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down()
end
```

### Worker-only machine (future consideration)

If sync volume grows to require dedicated worker capacity, Fly supports running a separate process group using a `[processes]` section in `fly.toml`. The web process runs Phoenix with HTTP enabled; the worker process runs only Oban with `PHX_SERVER=false`.

```toml
# fly.toml — future multi-process configuration
[processes]
  web = "/app/bin/server"
  worker = "/app/bin/metric_flow start"

[env]
  # Set per process via fly.toml [processes] env or fly secrets
```

For the worker process, disable the HTTP server and disable queues on the web process:

```elixir
# config/runtime.exs — add when implementing dedicated workers
if System.get_env("WORKER_ONLY") == "true" do
  config :metric_flow, MetricFlowWeb.Endpoint, server: false
  config :metric_flow, Oban, queues: [default: 10, sync: 5]
else
  # Web machines: disable sync queue to avoid split Oban load
  config :metric_flow, Oban, queues: [default: 10]
end
```

On a dedicated Oban worker node, also disable web-only plugins and set `peer: false` if the node should never become leader (though the default leader election is safe to leave enabled on worker nodes).

---

## Quick-Reference Checklist for First Deploy

1. Run `fly launch` and inspect generated files
2. Fix path dependencies (`client_utils`, `sexy_spex`) before remote build
3. Set `PHX_HOST = "metricflow.app"` in `fly.toml`
4. Verify `[deploy] release_command` is set in `fly.toml`
5. Move Cloak key to `init/1` callback, remove from `config.exs`
6. Set required secrets: `fly secrets set SECRET_KEY_BASE=... CLOAK_KEY=... DATABASE_URL=...`
7. Set OAuth secrets: `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
8. Verify `rel/env.sh.eex` contains `ERL_AFLAGS`, `RELEASE_NODE`, `ECTO_IPV6`, `DNS_CLUSTER_QUERY`
9. Run `fly deploy`
10. Add wildcard certificate: `fly certs add "*.metricflow.app"`
11. Create `.github/workflows/deploy.yml` with `FLY_API_TOKEN` secret in GitHub
12. Verify Oban tables exist: `oban_jobs`, `oban_peers`

---

## References

- [Deploying on Fly.io — Phoenix v1.8 official guide](https://hexdocs.pm/phoenix/fly.html)
- [Fly.io Elixir Getting Started](https://fly.io/docs/elixir/getting-started/)
- [BEAM Clustering Made Easy — The Phoenix Files](https://fly.io/phoenix-files/beam-clustering-made-easy/)
- [Clustering Your Application — Fly Docs](https://fly.io/docs/elixir/the-basics/clustering/)
- [Custom Domains — Fly Docs](https://fly.io/docs/networking/custom-domain/)
- [Safe Ecto Migrations — The Phoenix Files](https://fly.io/phoenix-files/safe-ecto-migrations/)
- [How to Migrate Mix Release Projects — The Phoenix Files](https://fly.io/phoenix-files/how-to-migrate-mix-release-projects/)
- [GitHub Actions for Elixir CI/CD — Fly Docs](https://fly.io/docs/elixir/advanced-guides/github-actions-elixir-ci-cd/)
- [Continuous Deployment with GitHub Actions — Fly Docs](https://fly.io/docs/launch/continuous-deployment-with-github-actions/)
- [Oban Peer / Leadership documentation](https://hexdocs.pm/oban/Oban.Peer.html)
- [cloak_ecto runtime key configuration](https://hexdocs.pm/cloak_ecto/install.html)
