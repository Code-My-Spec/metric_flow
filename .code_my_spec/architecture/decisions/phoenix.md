# Phoenix Framework

## Status

Accepted

## Context

MetricFlow needs a web framework for building the analytics dashboard SaaS. Requirements
include: server-rendered pages with real-time updates, RESTful routes, OAuth callback
handling, WebSocket-based live UI, and multi-tenant routing.

## Options Considered

### Phoenix 1.8

The standard Elixir web framework with built-in support for Channels, PubSub, LiveView,
and Ecto integration.

- Mature ecosystem (10+ years), production-proven at scale
- Built-in `phx.gen.auth` for authentication scaffolding
- Convention-driven project structure with contexts for domain separation
- Integrated asset pipeline (esbuild + tailwind)
- Bandit HTTP server for HTTP/2 support

### Plug + Custom Framework

Minimal approach using Plug directly with custom routing and middleware.

- Maximum flexibility but significant boilerplate
- No conventions — every architectural decision is manual

## Decision

**Phoenix ~> 1.8.1 with Bandit web server.**

Phoenix 1.8 is the natural choice for an Elixir web application. It provides the full stack
needed for MetricFlow: route handling, LiveView for real-time dashboards, PubSub for
cross-process updates, and `phx.gen.auth` for the authentication foundation.

Bandit (`{:bandit, "~> 1.5"}`) replaces the legacy Cowboy server with a pure-Elixir HTTP
server supporting HTTP/2.

## Consequences

- Project follows Phoenix conventions: contexts for domain logic, LiveViews for UI,
  controllers for non-live endpoints (OAuth callbacks, session management)
- Asset pipeline uses esbuild and Tailwind via Mix tasks
- Phoenix upgrade path is straightforward — 1.8 is the current stable release
- `dns_cluster` enables BEAM clustering for multi-node deployment on Fly.io
