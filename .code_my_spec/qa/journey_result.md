# QA Journey Result

## Status

partial

## Journey Results

### Journey 1: New User Registration to First Dashboard

**Status:** not executed — session redirected to fix BDD spec failures (scope.account, subscription paywall)

### Journey 2: Account Administration and Team Management

**Status:** not executed

### Journey 3: Integration Dashboard and Data Sync

**Status:** not executed

### Journey 4: Correlation Analysis and AI Insights

**Status:** not executed

### Journey 5: Agency White-Label and Multi-Client Access

**Status:** not executed

## Issues

### ActiveAccountHook missing active_account_id

All billing/agency LiveViews accessed `current_scope.account.id` but the Scope struct only has `user`. Fixed by extending `ActiveAccountHook` to assign `active_account_id` alongside `active_account_name`. Updated 4 LiveView files (Plans, StripeConnect, Subscriptions, Checkout) and `RequireSubscriptionHook`.

### Paywalled routes reject test users without subscriptions

BDD spex tests for correlation/AI features were redirected to `/subscriptions/checkout` because `RequireSubscriptionHook` found no active subscription. Fixed by adding `owner_has_active_subscription` shared given that creates a billing subscription for the test user's account. Patched 22 spex files.

### Spex failure reduction

- Before fixes: 79 failures / 336 tests
- After fixes: 35 failures / 336 tests
- Remaining failures are feature-level (unimplemented billing routes, Stripe checkout flows, agency features)

## Evidence

No browser screenshots captured — journeys were not executed due to session pivot to BDD spec fixes.
