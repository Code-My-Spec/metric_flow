# Design Review

## Overview

Reviewed the MetricFlowWeb.AgencyLive live context and its 4 child components (Plans, StripeConnect, Subscriptions, Settings). The architecture cleanly separates agency billing management into focused views, each with a single route and clear domain boundary.

## Architecture

- **Separation of concerns**: Each LiveView handles a distinct agency function — plan CRUD (Plans), Stripe onboarding (StripeConnect), customer subscription dashboard (Subscriptions), and agency configuration (Settings).
- **Dependency boundaries respected**: Plans and Subscriptions depend on `MetricFlow.Billing`, StripeConnect depends on `MetricFlow.Billing`, Settings depends on `MetricFlow.Agencies`. No cross-LiveView dependencies.
- **Route structure**: Three standalone routes (`/agency/plans`, `/agency/stripe-connect`, `/agency/subscriptions`) and Settings embedded within `/accounts/settings`. Clean hierarchy with no overlapping routes.
- **Stripe Connect gate**: Plans correctly requires an active Stripe Connect account before allowing plan creation, preventing orphaned plans without payment capability.

## Integration

- **Plans -> Billing**: Creates, updates, and deactivates plans via `Billing.create_plan/2`, `Billing.update_plan/3`, `Billing.deactivate_plan/2`.
- **StripeConnect -> Billing**: Initiates Connect Express onboarding via `Billing.create_connect_account/1`, disconnects via `Billing.disconnect_stripe_account/2`.
- **Subscriptions -> Billing**: Lists agency subscriptions, calculates MRR, and cancels subscriptions via Billing context functions.
- **Settings -> Agencies**: Configures auto-enrollment rules and white-label branding via `Agencies.configure_auto_enrollment/3`, `Agencies.update_white_label_config/3`.
- **Context-level dependencies**: `MetricFlow.Billing` and `MetricFlow.Agencies` are both listed as dependencies, matching the child component needs.

## Conclusion

The AgencyLive context is ready for implementation. All specs are internally consistent, dependencies are validated, and routes are well-structured.
