# MetricFlowWeb.AgencyLive.StripeConnect

Stripe Connect onboarding for agency accounts. Guides agency admins through connecting their Stripe account to the platform via Stripe Connect Express onboarding. Displays current onboarding status, initiates the Stripe-hosted onboarding flow, and handles the return redirect. Shows account capabilities and payout status once connected. Only accessible to agency account owners and admins.

## Type

liveview

## Route

`/agency/stripe-connect`

## Params

None

## Dependencies

- MetricFlow.Billing

## Components

None

## User Interactions

- **phx-click="connect_stripe"**: Initiate Stripe Connect Express onboarding. Calls `Billing.create_connect_account/1` to create an Express account and generate an onboarding link. Redirects the agency admin to the Stripe-hosted onboarding UI.
- **phx-click="disconnect_stripe"**: Disconnect the agency's Stripe account. Calls `Billing.disconnect_stripe_account/2`. Requires confirmation. Updates the status display to "Not connected".
- **phx-click="refresh_status"**: Re-fetch the Stripe account status from the API. Updates onboarding_status and capabilities in the local record.

## Design

Layout: Single-column centered page with a status card and action buttons.

**Header**: "Stripe Connect" with subtitle "Connect your Stripe account to receive payments"

**Status card** (`.card`):
- Connection status badge: `.badge-success` "Connected", `.badge-warning` "Restricted", `.badge-ghost` "Not connected"
- When connected: show Stripe account ID, capabilities list, and disconnect button
- When not connected: show connect button (`[data-role=connect-stripe]`, `.btn-primary`)
- When restricted: show message about completing onboarding requirements and a link to resume

**Disconnect section** (connected only):
- Disconnect button (`[data-role=disconnect-stripe]`, `.btn-error btn-outline`) with `data-confirm` prompt
- Warning text about impact on existing customer subscriptions

Responsive: Card stacks vertically on mobile.

