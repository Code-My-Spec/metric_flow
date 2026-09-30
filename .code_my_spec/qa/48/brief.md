# QA Story Brief — Story 48: Agency Plan Management

## Tool

web

## Auth

Log in via vibium MCP browser tools against this working copy's own instance (http://127.0.0.1:59302), not main's 4070.

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_scroll_into_view(selector: "#login_form_password")
browser_fill(selector: "#password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 5000)
```

QA Test Account (agency) is owned by qa@example.com per priv/repo/qa_seeds.exs.

## Seeds

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

Only if login as qa@example.com fails — seeds are idempotent and normally already in place.

## What To Test

This is a targeted retest of the two issues left partial by the prior attempt (30c52318, 40e41769), now that this checkout's own app can be tested directly (no promotion/spex-gate blocker on this copy).

- **Regression check (code + exunit, per plan.md's documented Stripe-Connect-disabled limitation):** confirm commit 5dc07a9 ("rotate Stripe Price on plan price update; decouple edit button from Stripe connection") is present in this checkout's `git log`, and `mix test test/metric_flow_web/live/agency_live/plans_test.exs test/metric_flow/billing_test.exs` passes in full, specifically:
  - `updating price rotates the Stripe Price and leaves the Product unchanged` (covers issue 30c52318 / criterion 423, 465)
  - `editing an existing plan is not blocked by a disconnected Stripe account` (covers issue 40e41769)
- **Live browser check:** navigate to the agency Plans page as qa@example.com, open the edit form on an existing plan, and confirm the Update button is not disabled by the agency's Stripe-connected state (only Create is gated) — matches `disabled={!@editing_plan_id && !@stripe_connected}` in `plans.ex:100`.
- Live confirmation of the actual Stripe Price rotation call itself is out of scope for this pass — the platform's Stripe test account has Connect disabled (documented in `.code_my_spec/qa/plan.md`), so that behavior is verified via the exunit suite above, consistent with the prior attempt's approach.

## Result Path

.code_my_spec/qa/48/result.md (not read by the harness — findings go through create_issue/submit_qa_result only)
