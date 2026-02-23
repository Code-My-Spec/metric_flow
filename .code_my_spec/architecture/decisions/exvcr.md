# ExVCR / HTTP Recording Strategy

## Status

Rejected (in favor of ReqCassette + TestRecorder)

## Context

MetricFlow integrates with external APIs (Google Analytics, Google Ads, Facebook Ads,
QuickBooks) for data sync. Integration tests need deterministic HTTP responses without
hitting real APIs.

ExVCR is the most popular HTTP recording library in the Elixir ecosystem, supporting
Hackney, HTTPoison, and ibrowse adapters.

## Options Considered

### ExVCR

Records and replays HTTP interactions via adapter-level interception.

- 700+ GitHub stars, mature library
- Supports Hackney and HTTPoison adapters
- JSON and custom cassette formats

### ReqCassette + TestRecorder

Two-layer approach matching MetricFlow's two HTTP clients:
- ReqCassette for Req-based API calls (Google Ads, Facebook, QuickBooks, OAuth)
- TestRecorder for function-level recording (Google Analytics via official client library)

## Decision

**ExVCR is not adopted.** It hooks into Hackney/HTTPoison, which is incompatible with:
- `Req` (~> 0.5) — MetricFlow's primary HTTP client, which uses Finch, not Hackney
- Google Analytics official client library — uses Tesla via `google_gax`

Instead, MetricFlow uses ReqCassette (Req-native) and TestRecorder (function-level
recording). See `e2e_testing.md` for the full testing strategy.

## Consequences

- No ExVCR dependency in the project
- HTTP recording is handled by purpose-built tools matching the actual HTTP clients
- See `e2e_testing.md` for implementation details
