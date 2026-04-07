# Design Review

## Overview

Reviewed the MetricFlowWeb.InvitationLive live context and its 2 child LiveViews (Accept, Send). The architecture is sound — each view handles a distinct side of the invitation workflow with clear separation between sending and accepting.

## Architecture

- **Separation of concerns**: Send handles the admin-facing invitation management (form, pending list, cancellation); Accept handles the recipient-facing token validation and acceptance flow.
- **Authentication boundaries**: Send requires authentication + owner/admin role check in mount. Accept is accessible to both authenticated and unauthenticated users (in the `current_user` live session), correctly handling both flows.
- **Dependency boundaries**: Both views call through `MetricFlow.Invitations` as the primary context API. Send additionally uses `MetricFlow.Accounts` for account-level checks. No direct child module access.
- **Cross-context component**: Send references `AccountLive.Components.Navigation` for shared account section navigation — this component doesn't exist in code yet but is a reasonable shared component across account-related views.

## Integration

- **MetricFlow.Invitations**: Primary dependency for both views. Provides `get_invitation_by_token`, `accept_invitation`, `decline_invitation`, `list_invitations`, `send_invitation`, and `change_invitation`.
- **MetricFlow.Accounts**: Used by Send for account-level authorization checks.
- **Cross-view flow**: Accept redirects to `/accounts` on successful acceptance; Send links back to `/accounts/members`. No circular dependencies.

## Issues

- **Accept spec had stale `MetricFlow.Users` dependency**: The Accept spec listed `MetricFlow.Users` as a dependency, but the implementation only aliases `MetricFlow.Invitations`. Removed the stale dependency from the spec.

## Conclusion

The InvitationLive context is ready for implementation. The single issue (stale Users dependency in Accept spec) has been fixed. Both views have well-defined test assertions covering the key user flows.
