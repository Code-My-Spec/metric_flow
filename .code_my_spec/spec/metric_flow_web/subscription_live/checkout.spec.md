# MetricFlowWeb.SubscriptionLive.Checkout

Subscription checkout flow for direct users and agency customers. Displays available plans, initiates Stripe Checkout sessions, and handles post-checkout confirmation. For direct users, charges the platform's Stripe account. For agency customers, routes payment through the agency's connected Stripe account. Redirects to Stripe-hosted checkout and handles return URLs for success and cancellation. Requires authentication.

## Type

liveview

## Route

`/subscriptions/checkout`

## Params

None

## Dependencies

- MetricFlow.Billing

## Components

None

## User Interactions

- **phx-click="subscribe"**: Initiate a Stripe Checkout session for the selected plan. Calls `Billing.create_checkout_session/3` with the plan, account, and return URLs. Redirects to the Stripe-hosted checkout page.
- **phx-click="cancel_subscription"**: Cancel the current subscription at period end. Calls `Billing.cancel_subscription/2`. Updates the status display.

## Design

Layout: Single-column centered page with plan card and subscription status.

**Header**: "Choose Your Plan" with subtitle "Unlock AI features with a subscription"

**Plan card** (`.card`):
- Plan name (e.g., "MetricFlow Pro")
- Monthly price displayed prominently
- Feature list: Correlations, Intelligence, Visualizations
- Subscribe button (`[data-role=subscribe-button]`, `.btn-primary`)

**Active subscription display** (when subscribed):
- Status badge: `.badge-success` "Active", `.badge-warning` "Past due", `.badge-ghost` "Cancelled"
- Current period dates
- Cancel button with confirmation

**Agency variant**: When user is under an agency, show agency plans instead of platform default.

Responsive: Card centers on desktop, full-width on mobile.

## Test Assertions

- mounts and displays plan name and price
- shows subscribe button for free users
- shows active subscription status for subscribed users
- shows cancel option for subscribed users
- displays agency plans for agency customers instead of platform default
