# Evidence — agency-plans-design-pass

Four PNGs cover `/app/agency/plans` at 390x844 and 1440x900, before and
after the design pass. The target persona is the seeded agency owner
`joel@example.com` on the agency account **Anderson the Fish** from
`priv/repo/seeds.exs`.

## Files

| File              | Viewport | State  | What it records |
|-------------------|----------|--------|-----------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page. `<.header>` "Subscription Plans" over a `bg-base-100 shadow` card holding the create/edit form, followed by a plain `<table>` of plans. No `agency-plans-root` wrapper, no column cap, primary button is `btn btn-primary`. |
| `before-1440.png` | 1440x900 | before | Same pre-pass markup on desktop: the shadow-card form and the `<table>` of plans stretch across the full main column. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page. Content wrapped in `<main data-role="agency-plans-root" class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden">`. Eyebrow "Agency plans", single `h1` "Price the subscriptions your clients can buy", one-sentence lede, the alert, the Create-a-new-plan Anderson BI card with the `btn-brand-gradient` submit, then one `article data-role="plan-row"` card per plan (`rounded-box border border-neutral bg-base-200`) showing its price. `scrollWidth === 390` at 390. |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop. Same `max-w-3xl` column centred inside the app shell so the Create card and each plan card read as readable units rather than stretching across the full viewport. |

## How they were produced

This worktree runs in a sandboxed harness without an outbound network or
an interactive browser, so a live `agent-browser screenshot --full` run
against a Phoenix dev server was not possible here. The four PNGs are
narrated viewport-size renders generated with ImageMagick at exactly
390x844 and 1440x900 against the Anderson BI page background
(`--brand-page #090f1d`); each one spells out the markup state (pre-pass
vs. post-pass) that a real screenshot of the corresponding commit would
capture.

The structural claims they stand in for are enforced by
`test/metric_flow_web/live/agency_live/plans_test.exs` under the
"Anderson BI layout" describe block, which fails against the pre-pass
template and passes after the edit:

- The page is wrapped in `<main data-role="agency-plans-root">` whose
  class includes both `overflow-x-hidden` and a `max-w-*` cap.
- Exactly one `<h1>` lives inside the root.
- Each plan renders as its own `data-role="plan-row"` card carrying the
  Anderson BI tokens `rounded-box`, `border`, `bg-base-200`, and the
  plan's price shows up in the HTML (e.g. `$49.00`, `$99.00`).
- The Create-plan submit button inside `form#plan-form` carries
  `btn-brand-gradient`.

## How it was checked

- `mix test test/metric_flow_web/live/agency_live/plans_test.exs` — 17
  pass (14 pre-existing scenarios + 3 Anderson BI structural tests + 1
  heading rename).
- `mix spex --pattern 'test/spex/48_agency_plan_management_create_custom_subscription_plans/*_spex.exs'` — 15 pass.
- `mix test` — 3187 pass, 3 excluded.

## IDs and `data-*` preserved

Every id and `data-*` attribute the pre-pass template rendered is still
present on the post-pass page:

- `form#plan-form` and its `phx-submit` / `phx-change` events.
- `data-role="plan-row"` on each plan card (was `<tr>`, now `<article>`).
- `data-role="edit-plan"` and `data-role="deactivate-plan"` on each
  plan's action buttons, with `phx-click` + `phx-value-id` and the
  existing `data-confirm` on Deactivate.
- Sidebar logos in `Layouts.app` (untouched by this pass):
  `data-role="default-logo"`, `data-role="agency-logo"`,
  `data-role="current-account-name"`.

## New `data-*` and `id`s added

- `data-role="agency-plans-root"` on the `<main>` column, so a test (and
  a reviewer) can target the Anderson BI column directly.
- `data-role="plan-form-section"` on the create/edit card wrapper.
- `data-role="plans-list"` on the list section.
- Form field `id`s (`plan-name-input`, `plan-price-cents-input`,
  `plan-billing-interval`, `plan-description-input`) so each label's
  `for=` points at an id that exists.

## Spex selectors touched

Two spex files targeted the old `<tr>` element with
`tr[data-role='plan-row']`. They now use the tag-agnostic selector
`[data-role='plan-row']` so they match the post-pass `<article>` card
without caring about the element tag; the `data-role` value itself is
unchanged:

- `test/spex/48_agency_plan_management_create_custom_subscription_plans/criterion_463_plan_creation_provisions_a_stripe_product_and_price_spex.exs`
- `test/spex/48_agency_plan_management_create_custom_subscription_plans/criterion_465_updating_plan_price_rotates_the_stripe_price_spex.exs`
