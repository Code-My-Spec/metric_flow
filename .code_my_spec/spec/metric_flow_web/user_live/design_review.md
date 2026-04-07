# Design Review

## Overview

Reviewed MetricFlowWeb.UserLive context with 4 listed LiveViews (Login, Registration, Confirmation, Settings) and 3 available child specs. The architecture is sound after fixing missing context-level dependencies. Confirmation has an implementation but no spec file yet.

## Architecture

- Clean separation: Registration handles signup, Login handles authentication (magic link + password + sudo), Settings handles email/password changes, Confirmation handles magic link token validation
- Registration correctly depends on Users, Accounts, and Agencies to create user, account, and handle agency account type
- Login and Settings depend only on Users — minimal coupling
- Settings uses sudo mode pattern for sensitive operations, delegating actual session work to controller via `phx-trigger-action`
- Login supports dual auth paths (magic link and password) with sudo re-auth mode — all in one view, appropriate for the compact auth flow

## Integration

- Registration links to Login (`/users/log-in`) for existing users
- Login links to Registration (`/users/register`) for new users; hides this link in sudo mode
- Login delivers magic link tokens pointing to Confirmation (`/users/log-in/:token`)
- Settings delivers email confirmation tokens pointing to itself (`/users/settings/confirm-email/:token`)
- Password changes POST to `UserSessionController` via `phx-trigger-action` for server-side session handling
- All views use router-level auth plugs for access control

## Issues

- **Context spec missing `MetricFlow.Accounts` and `MetricFlow.Agencies` dependencies**: Registration depends on both for account creation during signup. Added to context-level dependencies.

## Conclusion

The UserLive context is ready for implementation. The Confirmation LiveView has an implementation file but no spec — a stub will be created when the context spec is next evaluated. All other specs are consistent and dependencies verified.
