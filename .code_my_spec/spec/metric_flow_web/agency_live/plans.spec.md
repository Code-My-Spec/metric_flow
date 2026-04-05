# MetricFlowWeb.AgencyLive.Plans

Agency subscription plan management. Allows agency admins to create, edit, and deactivate custom subscription plans for their clients. Each plan defines a name, price, billing interval, and description. Plans are synced to Stripe as Price objects under the agency's connected Stripe account. Requires an active Stripe Connect account before plans can be created.

## Type

liveview

## Route

`/agency/plans`

## Params

None

## Dependencies

- MetricFlow.Billing

## Components

None

## User Interactions

- **phx-submit="create_plan"**: Submit the new plan form with name, price_cents, and billing_interval. Calls `Billing.create_plan/2`. On success, flash "Plan created" and append the new plan to the list. On validation error, re-render with inline field errors.
- **phx-click="edit_plan"**: Open the edit form for an existing plan, pre-filled with current values. Sets `editing_plan_id` in assigns.
- **phx-submit="update_plan"**: Submit the edited plan form. Calls `Billing.update_plan/3`. On success, flash "Plan updated" and refresh the list. On error, show inline errors.
- **phx-click="deactivate_plan"**: Deactivate the selected plan. Calls `Billing.deactivate_plan/2`. On success, flash "Plan deactivated" and update the plan's status badge. Requires confirmation.
- **phx-change="validate_plan"**: Live-validate plan form inputs as the user types.

## Design

Layout: Single-column page with a header, plan creation form, and plans list table.

**Header**:
- Page title: "Subscription Plans"
- Description: "Manage plans for your agency customers"

**Stripe Connect gate**:
- If agency has no connected Stripe account, show an alert `.alert-warning` with message "Connect your Stripe account before creating plans" and a link to `/agency/stripe-connect`
- Plan creation form and actions are disabled when Stripe is not connected

**Plan creation form** (`id="plan-form"`, `phx-submit="create_plan"`, `phx-change="validate_plan"`):
- Plan Name input (`.input`, required)
- Monthly Price input (`.input`, type number, in cents, required)
- Billing Interval select: Monthly, Yearly
- Description textarea (`.textarea`, optional)
- Submit button: `.btn-primary` "Create Plan"

**Plans list table** (`.table`):
- Columns: Name, Price, Interval, Stripe Price ID, Status, Actions
- Status badge: `.badge-success` "Active" or `.badge-ghost` "Inactive"
- Actions: Edit button (`[data-role=edit-plan]`), Deactivate button (`[data-role=deactivate-plan]`)
- Empty state: "No plans created yet"

Responsive: Table scrolls horizontally on mobile. Form stacks vertically.

## Test Assertions

- mounts and displays "Subscription Plans" heading
- shows Stripe Connect warning when agency has no connected Stripe account
- lists existing plans with name, price, and status
- shows empty state when no plans exist
- plan creation form is disabled when Stripe is not connected
- creates a new plan on valid form submission
- displays validation errors for missing required fields
- opens edit form when edit button is clicked
- updates plan on valid edit submission
- deactivates plan when deactivate button is clicked
- deactivated plan shows inactive badge
