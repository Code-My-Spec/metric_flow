# MetricFlowWeb.InvitationLive

Invitation management UI views.

## Type

live_context

## LiveViews

### InvitationLive.Send

- **Route:** `/accounts/invitations`
- **Description:** Allows account members to send invitations to new users, listing pending and accepted invitations for the active account.

### InvitationLive.Accept

- **Route:** `/invitations/:token`
- **Description:** Invitation acceptance page. Validates the invitation token and allows both authenticated and unauthenticated users to join the inviting account.

## Components

None

## Dependencies

- MetricFlow.Invitations
- MetricFlow.Accounts
