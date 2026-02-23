# Environment Variable Management

## Status

Proposed

## Context

MetricFlow requires configuration for:

- OAuth credentials (Google, Facebook, QuickBooks client IDs and secrets)
- Database connection strings
- Email provider API keys (Postmark)
- LLM API keys (Anthropic)
- Encryption keys (CloakEcto vault)
- Fly.io deployment secrets

Phoenix uses `config/runtime.exs` for runtime configuration from environment variables.
During development, developers need a way to manage these variables locally without
committing them to version control.

## Options Considered

### Dotenvy

Elixir library for loading `.env` files into the application environment at runtime.

- Integrates with `config/runtime.exs`
- Supports `.env`, `.env.local`, and environment-specific files
- Type casting for environment variables
- 200+ GitHub stars, actively maintained

### direnv

Shell-level environment variable management using `.envrc` files.

- Language-agnostic — works with any tool
- Loads variables into the shell session, not the application
- Requires developer setup (install direnv, allow the directory)
- Variables available to all processes, not just the Elixir app

### Manual export / .env with source

Manually source a `.env` file or export variables in shell profile.

- No dependency
- Easy to forget, inconsistent across team members
- No type casting or validation

## Decision

**Dotenvy for local development environment variable management.**

Dotenvy loads `.env` files in `config/runtime.exs` during development, providing a
consistent way to manage secrets locally. In production (Fly.io), environment variables
are set via `fly secrets set` and read directly from the OS environment.

Usage in `config/runtime.exs`:
```elixir
if config_env() != :prod do
  Dotenvy.source([".env", ".env.#{config_env()}"])
end
```

## Consequences

- Add `{:dotenvy, "~> 0.8"}` to `mix.exs` (all environments except `:prod`)
- Create `.env.example` with all required variables (no values) for developer onboarding
- Add `.env` and `.env.*` to `.gitignore`
- Production uses Fly.io secrets — no Dotenvy in production
- Developers copy `.env.example` to `.env` and fill in their credentials
