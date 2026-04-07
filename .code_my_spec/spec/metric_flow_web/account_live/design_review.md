# Design Review

## Overview

Reviewed MetricFlowWeb.AccountLive context with 3 child LiveViews: Index, Members, and Settings. The architecture is sound after fixing two consistency issues. Each view handles a distinct aspect of account management with appropriate authorization boundaries.

## Architecture

- Clean separation: Index handles account listing/switching/creation, Members handles member management, Settings handles configuration/transfer/deletion
- Index depends on Accounts and Agencies (for agency grant display); Members depends only on Accounts; Settings depends on Accounts and Users (password verification for deletion)
- All three views subscribe to PubSub for real-time updates — consistent pattern
- Authorization is well-layered: role-based visibility of controls (owner/admin vs read_only) with backend enforcement via Accounts.Authorization

## Integration

- Index allows switching active account, which affects the scope used by Members and Settings
- Settings delegates to Members list for ownership transfer target selection
- Settings links back to `/accounts` after account deletion
- All views scope data via `current_scope` for multi-tenant isolation
- AgencyLive.Settings (function component) is rendered within AccountLive.Settings for team accounts — cross-context integration handled cleanly

## Issues

- **Settings listed non-existent component `AccountLive.Components.Navigation`**: No such module exists in the codebase. Removed from the Components section.
- **Context spec missing `MetricFlow.Users` dependency**: Settings depends on Users for password verification during account deletion. Added to context-level dependencies.

## Conclusion

The AccountLive context is ready for implementation. All dependencies are verified, specs are consistent, and the two issues found have been fixed.
