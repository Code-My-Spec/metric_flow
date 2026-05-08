# Observability on Hetzner — AppSignal

**Status:** Accepted
**Date:** 2026-05-07
**Supersedes:** `monitoring_observability.md` (Sentry + PromEx + Fly metrics, 2026-02-21)

## Context

Two things changed between the prior ADR and this one:

1. **Deployment moved off Fly.io.** MetricFlow now runs on Hetzner under
   Kamal, with a kamal-proxy fronting per-app containers. Fly's managed
   Prometheus + Grafana — the chosen APM destination in the old ADR —
   doesn't exist here. PromEx was in deps but never had a scrape target
   to ship to.
2. **Single-operator complexity matters more than per-event cost.**
   The old ADR explicitly named AppSignal as the fallback when "APM and
   error tracking must be combined in one vendor … to reduce tooling
   complexity for a solo developer." That's the situation now: one
   person operating four apps across two boxes.

The prior ADR's Sentry deps and config blocks were partially wired
(`config/config.exs`, `config/runtime.exs`) but never deployed with a
DSN. PromEx was wired in `MetricFlowWeb.PromEx` and exposed a `/metrics`
route but had no scraper.

Box-level metrics (host CPU/RAM/disk, container restarts, Postgres
internals) are a separate concern handled at the infra layer by Grafana
Alloy → Grafana Cloud Free, scraping `node_exporter` + `cadvisor` +
`postgres_exporter` on each Hetzner box. That's tracked in
`devops/dev-posture-plan.md` Phase 4b and is independent of this ADR —
this ADR only covers application-level signals (errors, request traces,
LiveView, Ecto, Oban).

## Decision

**Use AppSignal as the single source of application-level observability:
errors, request traces, LiveView events, Ecto query timing, Oban job
performance, and alerting.**

No Sentry, no PromEx, no /metrics endpoint on the Phoenix app.

## Rationale

- **Elixir-first vendor.** AppSignal's `appsignal` and `appsignal_phoenix`
  packages are first-party, actively maintained, and integrate with
  Phoenix, LiveView, Ecto, and Oban via telemetry attachment with no
  manual instrumentation.
- **Single dependency for error tracking + APM + alerting.** Removes
  the "two separate tools, two separate alert configurations" cost the
  old ADR flagged for Sentry+PromEx.
- **Env-var-driven config composes cleanly with SSM-bootstrap.** All
  AppSignal runtime config (`APPSIGNAL_PUSH_API_KEY`, `APPSIGNAL_APP_NAME`,
  `APPSIGNAL_APP_ENV`) is loaded from SSM by `MetricFlow.Secrets.load!/1`
  at boot — same pattern as every other secret.
- **Free tier sufficient for current load.** 50K requests/month covers
  the current account count. Paid tier ($19/mo) is small relative to
  the operator-time cost of running two tools.
- **PromEx removal isn't a regression.** PromEx was in deps but had no
  destination — Fly metrics is gone. Adding alloy + Grafana Cloud is
  separately tracked at the box layer for non-app metrics.

## Consequences

### Dependencies

```elixir
# mix.exs
{:appsignal, "~> 2.16"},
{:appsignal_phoenix, "~> 2.5"}
```

Removed: `{:sentry, "~> 11.0"}`, `{:prom_ex, "~> 1.11"}`.

### Configuration

```elixir
# config/config.exs — bare minimum to start the :appsignal OTP app
config :appsignal, :config, otp_app: :metric_flow

# config/test.exs — agent off in CI
config :appsignal, :config, active: false
```

No `config/runtime.exs` block needed. AppSignal reads `APPSIGNAL_*` env
vars at OTP-app start, which happens after `MetricFlow.Secrets.load!/1`
returns from `runtime.exs` and after `System.put_env` has populated the
process env.

### Endpoint

```elixir
defmodule MetricFlowWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :metric_flow
  use Appsignal.Phoenix
  ...
end
```

`use Appsignal.Phoenix` attaches Phoenix endpoint + router instrumentation.
Ecto and Oban are attached via telemetry automatically when their apps
start.

### SSM keys

| Key                             | Type           | Value (per env)        |
|---------------------------------|----------------|------------------------|
| `APPSIGNAL_PUSH_API_KEY`        | SecureString   | (org-level push key)   |
| `APPSIGNAL_APP_NAME`            | String         | `metric_flow`          |
| `APPSIGNAL_APP_ENV`             | String         | `prod` or `uat`        |

The push API key is shared across environments. AppSignal segments
prod vs uat by `APPSIGNAL_APP_ENV` within a single named app.

### Removed code

- `lib/metric_flow_web/prom_ex.ex`
- The `/metrics` route in `lib/metric_flow_web/router.ex`
- `MetricFlowWeb.PromEx` from the `MetricFlowWeb.Application` supervision
  tree
- Sentry config blocks in `config/config.exs`, `config/runtime.exs`,
  `config/test.exs`
- PromEx test-disable block in `config/test.exs`

### LiveDashboard

The old ADR also recommended exposing LiveDashboard in production
behind admin auth. That's still a good idea but is independent of the
vendor choice and isn't blocked on anything in this ADR. Tracked
separately if/when it becomes useful.

### Custom business metrics

The old ADR's section on custom telemetry events (sync success rates,
API call counts per provider, token expiry events) still applies — emit
via `:telemetry.execute/3` and AppSignal will surface them as custom
metrics. No PromEx plugin module needed. Defer specific metric
definitions until a real question motivates one.
