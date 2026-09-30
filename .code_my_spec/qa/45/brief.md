# Qa Story Brief — Story 45: Feature Gate: Paywall AI Features for Free Users

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server, PID 95498, DB `metric_flow_dev_wc_bd0baac8` — NOT port 4070 from the general QA plan, and NOT main's checkout).

Log in once as the QA owner and use the in-app account switcher to move between accounts — do not log out/in for each scenario:

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_scroll_into_view(selector: "#login_form_password")
browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 5000)
```

`qa@example.com` (user id 2) is already a member/owner of every account needed below except accounts 1 and 32 — those two get a temporary `read_only` membership row added in Seeds so the same login can reach them via the account switcher.

## Seeds

No base seed re-run needed — `qa@example.com` already exists in this worktree's DB. Fixture accounts confirmed via direct query before writing this brief:

```
psql -d metric_flow_dev_wc_bd0baac8 -t -c "select bs.account_id, a.name, a.type, bs.status, bs.plan_id, p.agency_account_id from billing_subscriptions bs join accounts a on a.id=bs.account_id left join billing_plans p on p.id=bs.plan_id order by bs.account_id;"
```

Relevant accounts already in place:

| account_id | name | type | subscription | plan.agency_account_id | role for this brief |
|---|---|---|---|---|---|
| 14 | Client Alpha | client | none (free) | — | free user |
| 21 | QA Test Account | client | active, plan 1 | null (global plan) | subscribed direct user |
| 31 | QA Agency 1101 | agency | none | — | agency account bypass |
| 32 | QA47 Customer | client | past_due, plan 4 | 21 (non-null) | agency customer flagged-but-subscribed |
| 1 | Desert First Cleaning | client | past_due, plan null | — (no plan) | past_due, non-agency → re-paywalled |

Grant qa@example.com temporary read_only access to accounts 1 and 32 (idempotent):

```bash
psql -d metric_flow_dev_wc_bd0baac8 -c "insert into account_members (account_id, user_id, role, inserted_at, updated_at) select 1, 2, 'read_only', now(), now() where not exists (select 1 from account_members where account_id=1 and user_id=2);"
psql -d metric_flow_dev_wc_bd0baac8 -c "insert into account_members (account_id, user_id, role, inserted_at, updated_at) select 32, 2, 'read_only', now(), now() where not exists (select 1 from account_members where account_id=32 and user_id=2);"
```

After testing, remove these two temporary rows to leave the fixtures as found:

```bash
psql -d metric_flow_dev_wc_bd0baac8 -c "delete from account_members where account_id in (1,32) and user_id=2;"
```

## What To Test

- **405/495 — Free user full access to Dashboard/Integrations.** Switch to account 14 (Client Alpha, no subscription). Visit `/app/dashboard` and `/app/integrations`. Expect normal content, no `[data-role='paywall']` anywhere.
- **406/496/411/503/412/504 — Paywall on every AI route, direct URL.** Still as account 14, navigate directly (fresh URL load, not a link click) to each: `/app/correlations`, `/app/correlations/goals`, `/app/insights`, `/app/chat`, `/app/visualizations`, `/app/visualizations/new`. Expect `[data-role='paywall']` / `[data-role='upgrade-modal']` on every one instead of feature content — the same `RequireSubscriptionHook` gate is attached to all of them in `router.ex`'s `:require_subscription` live_session.
- **407/497 — Paywall states plan and price.** On any of the above paywalled pages, confirm the modal text includes a plan name and `/month` price (rendered from `[data-role='paywall-plan-name']`/price text — check `lib/metric_flow_web/components/core_components.ex` `paywall_modal/1` for exact markup).
- **408/498 — CTA routes to checkout.** Click the `[data-role='paywall-cta']` button. Expect navigation to `/app/subscriptions/checkout`.
- **410/502 — Server-side enforcement.** Confirm (via `browser_get_html`) that no correlation/visualization/insight data ever appears in the paywalled page's HTML for the free user — the gate assigns `:paywall` and swaps the whole `render/1` clause before any feature data is fetched, so nothing sensitive should be in the DOM to tamper with client-side.
- **409/499 — Subscribed direct user full access.** Switch to account 21 (QA Test Account, active subscription). Visit `/app/correlations`, `/app/visualizations`, `/app/insights`, `/app/chat`. Expect full feature content, no paywall.
- **409 (agency bypass) — Agency account never paywalled.** Switch to account 31 (QA Agency 1101, agency type, no subscription at all). Visit `/app/correlations`. Expect no paywall — agency-type accounts bypass the gate unconditionally in `RequireSubscriptionHook.on_mount/4`.
- **500 — Agency customer flagged-but-subscribed keeps access.** Switch to account 32 (QA47 Customer, `past_due`, plan 4 whose `agency_account_id` is non-null). Visit `/app/visualizations`. Expect full content, no paywall — this is the exact branch `has_active_subscription?/1` special-cases.
- **501 — Past_due with no agency plan is re-paywalled.** Switch to account 1 (Desert First Cleaning, `past_due`, no plan at all). Visit `/app/correlations`. Expect the paywall to reappear.

## Result Path

No result.md — findings go through `create_issue` as discovered; final outcome via `submit_qa_result` on task `92ee85fc-77e8-4d68-8af6-64090ae0a7cc`.

## Setup Notes

The component under test also covers `MetricFlowWeb.AiLive.Chat` per the prompt's linked-component note — `/app/chat` and `/app/chat/:id` are in the same `:require_subscription` live_session, so the Chat scenarios above cover its paywall gating specifically.

Note `/app/reports/generate` (`AiLive.ReportGenerator`) is NOT in the `:require_subscription` live_session per `router.ex` — it's a separate route outside this story's scope (not named in the story's AI-feature list of Correlations/Intelligence/Visualizations), so it is not tested here.
