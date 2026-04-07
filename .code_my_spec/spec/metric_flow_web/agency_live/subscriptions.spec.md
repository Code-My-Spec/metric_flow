# MetricFlowWeb.AgencyLive.Subscriptions

Agency customer subscription management dashboard. Displays all active, past-due, and cancelled subscriptions across the agency's client accounts. Shows subscription status, plan details, current period, and payment history. Allows agency admins to view customer billing details and cancel subscriptions.

## Type

liveview

## Route

`/agency/subscriptions`

## Params

None

## Dependencies

- MetricFlow.Billing

## Components

None

## User Interactions

- **phx-change="search"**: Filter the customer subscription list by name or email. Updates the displayed list in real-time as the user types.
- **phx-click="cancel_customer_subscription"**: Cancel a specific customer's subscription at period end. Calls `Billing.cancel_subscription/1` via the agency's connected Stripe account. Requires confirmation.
- **phx-click="next_page"** / **phx-click="prev_page"**: Paginate through the customer subscription list.

## Design

Layout: Single-column page with summary stats and a searchable customer table.

**Header**: "Customer Subscriptions" with subtitle "Manage your agency's subscriber accounts"

**Summary stats** (`.stat` cards in a row):
- Active Subscribers count
- Monthly Recurring Revenue (MRR) calculated from local plan price data
- Past Due count

**Search bar**: Text input for filtering by customer name or email

**Customer table** (`.table`):
- Columns: Customer, Plan, Status, Start Date, Period End, Actions
- Status badges: `.badge-success` Active, `.badge-warning` Past due, `.badge-ghost` Cancelled, `.badge-info` Trialing
- Actions: Cancel button for active subscriptions
- Pagination controls at bottom
- Empty state: "No customer subscriptions yet"

Responsive: Stats stack vertically on mobile. Table scrolls horizontally.
