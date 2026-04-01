# MetricFlow.Integrations.OauthStateStore

Server-side ETS-backed store for OAuth session params, keyed by the OAuth `state` token. Runs as a named GenServer that owns the ETS table and periodically purges expired entries. Avoids any reliance on cookies or the Phoenix session, which can be stripped by reverse proxies during 302 redirects.

## Type

module

## Dependencies

- None

## Functions

