# Design Review

## Overview

This review covers the `MetricFlow.Invitations` context, a standalone context with no child component modules currently specified. The spec was in a skeletal state — the `## Functions` section was empty — which has been corrected. The context is now minimally coherent and unblocked for initial implementation, though it requires child schema and repository modules before it can be considered architecturally complete.

## Architecture

- The context correctly sits at the domain layer with no LiveView or web dependencies. Both `InvitationLive.Accept` and `InvitationLive.Send` declare `MetricFlow.Invitations` as a dependency, which is the correct direction.
- The `Accept` LiveView spec calls `get_invitation_by_token/1`, `accept_invitation/2`, and `decline_invitation/2`. The `Send` LiveView spec references `create_invitation/3` by implication (it exists to send invitations). All four functions were missing from the context spec and have now been added.
- The dependency list has been updated from `None` to `MetricFlow.Accounts` and `MetricFlow.Users`. `accept_invitation/2` must create an `AccountMember` record, which belongs to the Accounts domain. The `Scope` struct used for authorization comes from `MetricFlow.Users.Scope`.
- The architecture overview lists `Invitations` as a leaf context with no declared dependencies, consistent with the updated spec (Accounts and Users are already present in the graph; Invitations takes a dependency on them, not the reverse).
- No child schema or repository modules exist yet. The context spec notes this as a gap. A production-ready implementation will require at minimum an `Invitation` schema and an `InvitationRepository`. These should be added to the spec before coding begins.
- The `accept_invitation/2` function creates cross-context data (an `AccountMember` record). This is an intentional design choice — the Invitations context orchestrates a workflow that touches the Accounts domain. The interaction should go through `MetricFlow.Accounts.add_user_to_account/4` rather than writing directly to the accounts tables, which would violate Boundary rules.

## Integration

- `InvitationLive.Accept` consumes `get_invitation_by_token/1`, `accept_invitation/2`, and `decline_invitation/2` from this context. All three are now defined in the spec with matching signatures and error tuples.
- `InvitationLive.Send` consumes `create_invitation/3`. The Send spec has an empty `## Functions` section; the function is now established on the context side.
- `accept_invitation/2` must delegate to `MetricFlow.Accounts.add_user_to_account/4` to create the membership. This keeps Invitations as an orchestrator and respects Boundary rules — Invitations may depend on Accounts, not the other way around.
- `get_invitation_by_token/1` is called without a `Scope` argument (unauthenticated users need to read the invitation details before deciding to log in). This is intentional and consistent with the Accept LiveView design, which assigns `current_user: nil` for unauthenticated visitors.
- `accept_invitation/2` and `decline_invitation/2` require an authenticated `Scope`, consistent with the LiveView interaction spec which only renders accept/decline buttons for logged-in users.

## Issues

- **Functions section was empty**: The context spec listed no functions despite two LiveView specs calling into it. All required functions (`get_invitation_by_token/1`, `accept_invitation/2`, `decline_invitation/2`, `create_invitation/3`) have been added with `@spec` typespecs, Process steps, and Test Assertions.
- **Dependencies were listed as None**: The context requires `MetricFlow.Accounts` (for `add_user_to_account/4` delegation during accept) and `MetricFlow.Users` (for the `Scope.t()` type). Both have been added to the Dependencies section.
- **No child components specified**: No `Invitation` schema or `InvitationRepository` module is defined. This is not blocking for a design review but must be addressed before implementation begins. The spec now notes this gap explicitly in the Components section.

## Conclusion

The context is ready for incremental implementation. The immediate next step before writing code is to add an `Invitation` schema component (fields: token, account_id, inviting_user_id, target_email, role, status, expires_at) and an `InvitationRepository` to the spec, following the patterns established in `MetricFlow.Accounts`. Once those child specs exist, this context can be implemented top-down without ambiguity.
