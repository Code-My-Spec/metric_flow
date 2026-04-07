# MetricFlowWeb.AgencyLive

Agency management and billing UI views.

## Type

live_context

## LiveViews

### AgencyLive.Plans

- **Route:** `/agency/plans`
- **Description:** Agency subscription plan management. Allows agency admins to create, edit, and deactivate custom subscription plans for clients. Requires an active Stripe Connect account.

### AgencyLive.StripeConnect

- **Route:** `/agency/stripe-connect`
- **Description:** Stripe Connect onboarding for agency accounts. Displays connection status, initiates Express onboarding, and allows disconnection.

### AgencyLive.Subscriptions

- **Route:** `/agency/subscriptions`
- **Description:** Agency customer subscription management dashboard. Displays subscriptions across client accounts with summary stats, search, pagination, and cancel actions.

## Components

### AgencyLive.Settings

Function component module rendered within the AccountLive.Settings page. Renders auto-enrollment and white-label branding configuration cards conditionally for team account owners and admins.

## Dependencies

- MetricFlow.Billing
- MetricFlow.Agencies
