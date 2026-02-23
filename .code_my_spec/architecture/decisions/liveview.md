# Phoenix LiveView

## Status

Accepted

## Context

MetricFlow's UI requires:

- Real-time dashboard updates (metric cards, charts refreshing on data sync)
- Interactive forms (account settings, integration configuration, correlation goals)
- Live status indicators (sync progress, job status)
- Server-driven navigation without full page reloads
- Minimal JavaScript footprint — charts are the only JS-heavy component

## Options Considered

### Phoenix LiveView 1.1

Server-rendered real-time UI framework. HTML is rendered on the server and pushed
to the client over WebSocket. User events are sent back to the server for processing.

- No client-side state management needed
- Forms, navigation, and interactions handled server-side
- JavaScript hooks available for client-side integrations (Vega-Lite charts)
- Built-in support for file uploads, streams, and async assigns

### React / Next.js SPA + Phoenix API

Separate frontend SPA communicating with a Phoenix JSON API.

- Requires maintaining two codebases (Elixir API + React frontend)
- Client-side state management complexity (Redux, React Query)
- Better for offline-first apps — not a MetricFlow requirement
- Larger JavaScript bundle sizes

### LiveView + Surface

LiveView with Surface library for component-oriented development with slots and props.

- Adds a compile-time component layer on top of LiveView
- Smaller community, additional dependency
- LiveView 1.1 has improved component support, reducing Surface's value

## Decision

**Phoenix LiveView ~> 1.1.0 as the primary UI framework.**

LiveView eliminates the need for a separate frontend framework. All dashboard pages,
settings forms, and interactive features are implemented as LiveViews with server-side
state management. JavaScript is only needed for the Vega-Lite chart hook (via vega-embed).

Key LiveView features used:

- **Live navigation** — `live_session` groups with authentication plugs
- **Async assigns** — loading states for external API data
- **PubSub integration** — real-time updates when sync jobs complete
- **Streams** — efficient list rendering for metrics, members, integrations
- **JS hooks** — Vega-Lite chart rendering via a `VegaLite` hook

## Consequences

- All UI state lives on the server — no client-side state management needed
- Each connected user maintains a WebSocket + server process (BEAM handles this efficiently)
- SEO for public pages requires dead views or `Phoenix.Controller` — not a concern for an
  authenticated dashboard app
- JavaScript bundle is minimal: LiveView client JS + vega-embed for charts
- Testing uses `Phoenix.LiveViewTest` — no browser required for most tests
