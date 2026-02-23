# Deployment and Hosting Platform

## Status
Proposed

## Context

MetricFlow is a Phoenix 1.8 LiveView SaaS application that needs a production hosting platform. The stack has specific requirements that constrain the options:

- **Phoenix LiveView with WebSockets** — persistent WebSocket connections per active user, managed by Bandit 1.5. These connections must survive across multiple application nodes, which means the platform must handle sticky sessions or distributed BEAM clustering.
- **Oban background jobs** — daily data sync jobs, correlation calculations, cron scheduling. Oban uses PostgreSQL as its backing store and relies on advisory locks to prevent duplicate execution. Across multiple nodes this requires either a single-node Oban setup or careful use of Oban's global limit configuration.
- **PostgreSQL** — the only supported database. Managed hosting is strongly preferred to avoid operational burden. The Cloak vault and Oban both depend on it directly.
- **OAuth callbacks** — Google, Facebook, and QuickBooks OAuth flows require publicly reachable HTTPS URLs. SSL certificate management must be handled by the platform.
- **Custom subdomains for agency white-labeling** — the `Agencies.WhiteLabelConfig` schema stores a unique `subdomain` per agency (e.g., `acme.metricflow.app`). The platform must support wildcard DNS and TLS certificates so traffic to `{agency}.metricflow.app` routes to the application and the application can determine the tenant from the host header.
- **Zero-downtime deployments** — Ecto migrations run ahead of the new release. Safe migration patterns (avoid locking writes, prefer concurrent index creation) must be possible without scheduled downtime.
- **CI/CD from GitHub** — the project already uses GitHub for source control. The deployment pipeline should trigger on push to `main`.
- **Telemetry** — `telemetry_metrics` and `telemetry_poller` are already in deps. The platform should offer an integration target (metrics endpoint, log aggregation) or not interfere with self-hosted observability tools.

The project is in early SaaS development. Cost at low account counts (~10–100) matters more than raw scalability ceiling.

## Options Considered

### Option A: Fly.io

Fly.io runs applications on lightweight VMs distributed globally. It is the primary Phoenix/Elixir platform recommended by the Phoenix core team, and has first-party documentation for deploying Phoenix releases with `fly launch`, clustering with `dns_cluster`, zero-downtime Ecto migrations, and GitHub Actions CI/CD.

**Pros:**
- `fly launch` detects Phoenix projects and auto-generates a Dockerfile, `fly.toml`, and release scripts including migration runners. Minimal manual setup.
- Built-in BEAM clustering via Fly's internal WireGuard mesh. Nodes discover each other over `{app}.internal` DNS. The `dns_cluster` library (already a project dependency) works without additional configuration once the env vars are set.
- WebSocket connections work natively. Multiple machines in the same region share the same Anycast IP; Fly's proxy uses long-lived TCP connections so LiveView sessions are not disrupted.
- Custom domains and wildcard TLS certificates are supported. `fly certs add "*.metricflow.app"` provisions a wildcard cert via DNS-01 challenge. This directly enables the agency white-label subdomain requirement. Certificates cost $0.10/month per hostname for non-wildcard; wildcard certs are DNS-01 verified and also low cost.
- First-party GitHub Actions workflow documentation for Elixir CI/CD. A single `fly deploy` command in a workflow step handles Docker build and deploy.
- Managed Postgres available (Fly Managed Postgres); alternatively, the legacy Fly Postgres (user-managed Postgres as a Fly app) is also available and cheaper.
- Low entry cost: a single `shared-cpu-1x` machine with 256 MB costs ~$2/month; with 512 MB ~$4/month. Two machines (for availability) + managed Postgres starter plan places the early SaaS cost under $50/month.
- `fly ssh console` provides direct iex shell access to the running node for debugging.

**Cons:**
- The Fly-managed Postgres Basic plan starts at ~$38/month, a significant step-up over alternatives at early scale. The legacy user-managed Postgres approach is cheaper but requires more operational care.
- Multi-region BEAM clustering requires IPv6 (`ECTO_IPV6=true`, `ERL_AFLAGS="-proto_dist inet6_tcp"`). While well-documented, it is non-obvious and adds initial configuration friction.
- Oban across multiple nodes requires careful queue configuration. Because Oban uses PostgreSQL advisory locks, duplicate execution is prevented by the database, but cron scheduling should be run on a single node or with Oban's `:global` option to avoid redundant scheduler firings. This is solvable but requires deliberate attention at the time of scaling beyond one machine.
- Custom domain WebSocket connections require `PHX_HOST` to be set to the custom domain and `check_origin` in the endpoint to enumerate allowed origins. This must be updated each time new agency subdomains are onboarded — or `check_origin: false` must be used (not recommended for security). The recommended pattern is to set `check_origin` to a list of allowed patterns or use a plug to dynamically validate origins against the database.
- Community feedback notes the CLI tooling can occasionally be frustrating and initial setup has a steeper learning curve than Render.

---

### Option B: Render

Render is a platform-as-a-service with git-push deploys, managed PostgreSQL, and automatic SSL.

**Pros:**
- Git-push deploys from GitHub with no Dockerfile required (Render builds from source using buildpacks). Also supports Docker if preferred.
- Managed PostgreSQL with a free tier (expires after 90 days) and paid plans starting at ~$7/month for starter instances.
- Custom domains with automatic SSL via Let's Encrypt. Wildcard domains are supported on paid plans.
- Dashboard-based Shell access to running services.
- As of mid-2024, Render added distributed Elixir cluster support, though community adoption is limited.
- Simpler UX than Fly.io for initial onboarding.

**Cons:**
- Web services spin down on the free tier (not relevant for production but noted). Paid web services start at ~$7/month.
- Render's distributed Elixir support is newer and less battle-tested in the Elixir community compared to Fly.io. Documentation is thinner.
- Overall cost per comparable workload is higher than Fly.io — community members describe Render as "much easier to setup, more expensive."
- No first-party Phoenix/Elixir deployment guide comparable in depth to Fly.io's Phoenix Files series. The developer experience for Elixir-specific features (releases, clustering, migrations) requires more manual configuration.
- WebSocket configuration for custom domains requires manually adding each domain to `check_origin`. No special platform support for multi-tenant host routing.

---

### Option C: Railway

Railway uses usage-based pricing (CPU seconds, RAM MB-seconds, bandwidth GB) and Nixpacks for automatic language detection.

**Pros:**
- Automatic Elixir/Phoenix detection with no Dockerfile required.
- Usage-based pricing means near-zero cost during low-traffic periods.
- Managed PostgreSQL provisioned instantly within a project.
- Private networking between services in the same project.

**Cons:**
- No meaningful Elixir community presence compared to Fly.io. Documentation for Phoenix-specific patterns (releases, clustering, Oban, migrations) is minimal.
- BEAM clustering across multiple Railway services is not documented or officially supported.
- Wildcard TLS certificates and custom domain per-tenant routing are not a documented use case on Railway. The white-label subdomain requirement is at best an unsupported configuration.
- Migration runners must be manually configured; Railway does not run migrations automatically before deploys.
- Less suitable for long-lived WebSocket workloads — the platform is primarily documented for web API/HTTP services.

---

### Option D: AWS ECS/Fargate with RDS

Running Phoenix in AWS ECS Fargate containers with Amazon RDS PostgreSQL.

**Pros:**
- Full control over infrastructure, networking, IAM, VPC, and security groups.
- RDS PostgreSQL is highly mature and available in many instance sizes. Multi-AZ failover is straightforward.
- Scales to arbitrary load with no platform-level constraints.
- Native integration with CloudWatch, X-Ray, and the broader AWS observability ecosystem.

**Cons:**
- Substantially higher operational complexity. Requires managing ECS task definitions, load balancer configuration (ALB with WebSocket support), ECR for Docker images, VPC setup, and IAM roles.
- BEAM clustering in ECS Fargate requires a custom service discovery setup (AWS Cloud Map or a custom DNS approach). Not well-documented for Elixir.
- Custom domain wildcard TLS requires ACM certificate provisioning and ALB listener rules.
- Cost at early scale is comparable to or higher than Fly.io once ALB, RDS, and Fargate task costs are combined. No low-cost entry tier.
- CI/CD requires separate configuration of ECR push, ECS task registration, and deployment triggers.
- Not appropriate for a team that wants to focus engineering time on product features rather than infrastructure.

---

### Option E: DigitalOcean App Platform with Managed Database

DigitalOcean App Platform with a managed PostgreSQL cluster.

**Pros:**
- Git-based deploys from GitHub. Dockerfile support available.
- Managed PostgreSQL starts at ~$15/month for a basic cluster.
- Custom domains with automatic SSL.
- Simpler than AWS. Good documentation for general web app deployment.

**Cons:**
- Elixir/BEAM clustering is not a documented or supported feature of the App Platform. There is no equivalent to Fly.io's internal WireGuard mesh.
- DigitalOcean App Platform enforces SSL on database connections, requiring `ssl: true` and `ssl_opts: [verify: :verify_none]` in Ecto config — a minor but non-obvious setup step.
- Wildcard TLS certificates for custom subdomains require using DigitalOcean's DNS hosting and configuring the certificate through their certificate manager. The per-tenant domain routing logic must be fully implemented in application code.
- No first-party Phoenix deployment documentation. Community guides are older and cover pre-release Phoenix versions.
- The App Platform product is a reasonable general-purpose PaaS but offers no specific advantages for the Elixir/Phoenix/Oban/LiveView stack.

## Decision

**Fly.io is recommended as the deployment platform.**

Fly.io is the best fit across every major requirement:

1. **WebSocket scaling** — Fly's proxy handles long-lived TCP connections natively. BEAM clustering with `dns_cluster` (already a project dependency at `dns_cluster ~> 0.2.0`) works out of the box after setting the env vars that `fly launch` generates.

2. **Custom subdomains for white-labeling** — Wildcard TLS certificates (`fly certs add "*.metricflow.app"`) with DNS-01 challenge support directly enable agency subdomain routing. No other option in this comparison offers this as a first-class feature with documented support.

3. **Oban on a single machine initially** — At early scale (10–100 accounts), running a single Fly Machine handles all Oban queues without cluster coordination concerns. The `queues: [default: 10, sync: 5]` configuration in `config.exs` is already suitable. When scaling to multiple machines, Oban's PostgreSQL advisory lock mechanism prevents duplicate execution across nodes; cron-based scheduling (the daily sync scheduler) should be configured with `Oban.Plugins.Cron` running on all nodes, which is safe because Oban's cron plugin uses database uniqueness to prevent duplicate insertions.

4. **Zero-downtime migrations** — Fly's release system supports a `release_commands` hook in `fly.toml` that runs `./bin/metric_flow eval MetricFlow.Release.migrate` before traffic is shifted to new instances. Combined with safe migration patterns (avoid exclusive locks, use `@disable_migration_lock true` for concurrent operations), this enables no-downtime schema changes.

5. **CI/CD** — Fly.io's official GitHub Actions documentation for Elixir covers the full pipeline: run tests against a Postgres service container, then `fly deploy` on merge to `main`. The `flyctl` GitHub Action handles authentication via `FLY_API_TOKEN`.

6. **Cost at early scale** — A single `shared-cpu-1x` machine with 512 MB RAM runs ~$4/month. For availability, two machines in the same region add ~$8/month. Combined with the Fly Managed Postgres Basic plan (~$38/month), total cost at launch is approximately **$46–50/month**. As an alternative to Managed Postgres, the legacy Fly Postgres (a Postgres app managed by the team) reduces this to approximately **$15–20/month** total, at the cost of handling Postgres upgrades manually.

The primary trade-off accepted is Fly.io's steeper initial CLI learning curve compared to Render. However, the depth of Phoenix-specific documentation (the Phoenix Files series, official Elixir guides) significantly reduces this friction.

## Consequences

**Immediate setup actions required:**

- Run `fly launch` to generate `Dockerfile`, `fly.toml`, and release configuration. Inspect the generated files and commit them.
- Configure required production secrets via `fly secrets set`:
  - `DATABASE_URL`
  - `SECRET_KEY_BASE`
  - `CLOAK_KEY` (or ensure the vault key is pulled from an env var in `runtime.exs` rather than hardcoded as it currently is in `config.exs`)
- Set `PHX_HOST` to `metricflow.app` (or the chosen production domain) in `fly.toml`.
- Enable BEAM clustering env vars in `rel/env.sh.eex` or `fly.toml`:
  ```
  ERL_AFLAGS="-proto_dist inet6_tcp"
  RELEASE_DISTRIBUTION=name
  RELEASE_NODE=<%= release_name %>@${FLY_PRIVATE_IP}
  ECTO_IPV6=true
  DNS_CLUSTER_QUERY=<app-name>.internal
  ```

**Custom domain / white-label setup:**

- Point `metricflow.app` at Fly via CNAME to the app's `fly.dev` subdomain.
- Issue a wildcard cert: `fly certs add "*.metricflow.app"`.
- Implement a `Plug` that reads `conn.host`, looks up the `WhiteLabelConfig` by subdomain, and assigns the agency context. This ensures `check_origin` validation works correctly — update `check_origin` in the endpoint configuration to accept the wildcard pattern or validate dynamically via `check_origin: {MyModule, :check_origin, []}`.

**Oban considerations:**

- Start with one Fly Machine. Add a second for availability only after validating the primary deployment works.
- When adding a second machine, verify `Oban.Plugins.Cron` behavior. Because Oban inserts cron jobs with uniqueness constraints, duplicate cron insertions are already prevented. No additional configuration is needed for the `sync` queue's daily scheduler.
- If daily sync volume grows to require dedicated worker capacity, Fly supports running a separate process group (a second app or a separate `fly.toml` process definition) with `PHX_SERVER=false` and only the Oban queues enabled.

**CI/CD pipeline:**

- Create `.github/workflows/deploy.yml` with two jobs: `test` (runs `mix test` against a Postgres service container) and `deploy` (runs `fly deploy --remote-only` on push to `main`). The `flyctl` action authenticates via the `FLY_API_TOKEN` repository secret.

**Observability:**

- `telemetry_metrics` and `telemetry_poller` are already present. Connect these to Fly's built-in metrics endpoint or export to a Prometheus-compatible collector. Fly provides a hosted metrics dashboard for basic VM and request metrics at no extra cost.
- For application-level metrics and log aggregation, Fly supports log shipping to external services (Datadog, Papertrail, Logtail) via `fly logs --app` drain configuration.

**Security note:**

- The Cloak vault encryption key is currently hardcoded in `config/config.exs` with a literal base64 key. Before deploying to production, this key must be moved to a runtime environment variable read in `config/runtime.exs`. Committing a production vault key to source control would expose all encrypted OAuth tokens.
