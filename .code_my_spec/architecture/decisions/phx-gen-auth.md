# phx.gen.auth Authentication

## Status

Accepted

## Context

MetricFlow needs user authentication (registration, login, session management, password reset)
as the foundation for all user-facing features. Phoenix 1.8 provides the `mix phx.gen.auth`
generator which scaffolds a complete authentication system.

## Options Considered

### phx.gen.auth (Built-in)

Phoenix's official authentication generator. Creates:

- `Users` context with `User` and `UserToken` schemas
- `UserAuth` plug pipeline for session management
- LiveView pages for registration, login, settings, password reset
- `Scope` struct carrying user and account context
- Email confirmation and magic link login support

### Pow

Third-party authentication library with extension system.

- More features out of the box (OAuth, invitation, etc.)
- Adds a dependency with its own conventions
- Less transparent — code lives in the library, not your project

### Custom Authentication

Build authentication from scratch.

- Maximum control but significant security risk
- bcrypt, token management, session handling all need careful implementation
- No community review of security patterns

## Decision

**`mix phx.gen.auth` as the authentication foundation.**

The generated code lives entirely in the project (no library dependency for auth logic),
uses `bcrypt_elixir` for password hashing, and provides the `Scope` struct pattern that
all contexts use for multi-tenant data isolation.

The generated code was extended with:
- `Scope` struct includes `active_account` and `active_account_id` for multi-tenant scoping
- `Accounts.Authorization` module for role-based access control (see `authorization_strategy.md`)
- Account-scoped sessions via `UserPreferences`

## Consequences

- Authentication code is fully owned by the project — maintained alongside application code
- `Scope` struct is the universal first parameter for all public context functions
- Password hashing via `bcrypt_elixir` (~> 3.0) — no external auth service dependency
- Session tokens stored in PostgreSQL via `UserToken` schema
- Email confirmation uses `UserNotifier` with Swoosh (see `email_provider.md`)
