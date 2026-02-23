# Elixir

## Status

Accepted

## Context

MetricFlow is a real-time analytics SaaS that requires:

- Concurrent handling of multiple external API data syncs
- Real-time UI updates for dashboards and sync status
- Background job processing for daily data syncs and correlation calculations
- Multi-tenant data isolation across accounts
- Long-running WebSocket connections for LiveView

## Options Considered

### Elixir / OTP

Functional language on the BEAM VM with built-in concurrency, fault tolerance, and
the OTP framework for building reliable distributed systems.

- First-class support for WebSockets, PubSub, and real-time features
- Process-per-connection model handles thousands of concurrent LiveView sessions
- Supervisor trees provide fault isolation — a failing sync job doesn't crash the app
- Pattern matching and immutable data structures reduce runtime errors
- Ecosystem: Phoenix, Ecto, Oban, LiveView — purpose-built for this type of application

### Node.js / TypeScript

Event-loop based runtime with large ecosystem.

- Single-threaded event loop can bottleneck on CPU-bound correlation calculations
- Requires external tools for background jobs (Bull, Agenda)
- Real-time requires additional infrastructure (Socket.io, Redis pub/sub)

### Ruby on Rails

Convention-over-configuration web framework.

- Strong ecosystem for CRUD SaaS, weaker for real-time and concurrency
- Background jobs via Sidekiq require Redis
- ActionCable for WebSockets is less mature than Phoenix Channels/LiveView

## Decision

**Elixir ~> 1.19 on the BEAM VM.**

The BEAM's concurrency model is uniquely suited for MetricFlow's requirements: concurrent
API syncs, real-time dashboard updates, background correlation calculations, and thousands
of concurrent LiveView connections — all without external infrastructure like Redis or
message queues.

## Consequences

- Team members must be proficient in functional programming and pattern matching
- Smaller hiring pool compared to JavaScript or Ruby
- Some third-party API client libraries are less mature than Node.js equivalents
  (mitigated by using raw Req for HTTP calls)
- Strong ecosystem for the specific problem domain (Phoenix, LiveView, Ecto, Oban)
