# Evidence — correlation-goals-design-pass

Browser screenshots of `/app/correlations/goals` on the seeded data in
`priv/repo/seeds.exs`, captured on a local `mix phx.server` (MIX_ENV=dev,
port 4086, database `metric_flow_dp_correlation_goals`) signed in as
`client@example.com` (password `hello world!`) — the seeded owner of
"Anderson Retail Co.", the account the seeds attach every seeded metric
to, so the Goals list card is populated (`ga_sessions`, `ga_conversions`,
`gads_clicks`, `gads_cost`, `fb_impressions`, `fb_ad_spend`, `qb_revenue`,
`qb_expenses`).

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned true and
`location.pathname === "/app/correlations/goals"` was confirmed. At 390,
`document.documentElement.scrollWidth === 390` was read back before the
shot. The before shots were captured on the same running server after
replacing `lib/metric_flow_web/live/correlation_live/goals.ex` with the
version at commit `1c7e6d0b` (the issue as handed in, trailer-free), so
Phoenix live_reload re-rendered with the pre-pass markup; the file was
restored before the after shots were confirmed and before this commit.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|---------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page. One undifferentiated column: page header, then the "Goal Metric" `mf-card` form (the class has no CSS rule, so no border or background draws), then the "Queue Multiple Goals" `mf-card`. Save Goal is a small daisyUI `btn btn-primary` the same shape and weight as Cancel beside it. Nothing names the two parts of the page; the queue block reads as a footnote to the form. |
| `before-1440.png` | 1440x900 | before | Pre-pass desktop page, same markup. Two full-width blocks with no visible card chrome, no section headings, and the small `btn btn-primary` Save — the one action this page exists for — is indistinguishable from Cancel. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page on the same seeds. Outer column `max-w-5xl mx-auto overflow-x-hidden` (`scrollWidth === 390`). Two labelled sections drawn with the DESIGN.md Card tokens (`bg-base-200 border border-neutral rounded-box`): `data-role="add-goal-section"` (h2 "Add a goal") and `data-role="goals-list-section"` (h2 "Goals list"). Save Goal is `btn-brand-gradient rounded-box px-4 py-2 w-full sm:w-auto` and stacks full-width above a Secondary-style Cancel; Queue Selected Goals is the same gradient Primary inside the goals-list card. |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop page, same markup. The two cards sit stacked in a centered `max-w-5xl` column with explicit headings and the gradient Save / Queue buttons sized to content on wider viewports. |

## What the pass does to the page (`lib/metric_flow_web/live/correlation_live/goals.ex`)

Ranked problems for Dana, the direct independent marketer
(`.code_my_spec/personas/direct-independent-marketer/summary.md`, who
self-funds the tool and wants "Clarity > Complexity"):

1. **The page had no visible structure.** Page header, single-select Save
   form, and multi-select Queue form stacked in one column with no section
   headings and no visible card chrome. On a phone Dana could not tell at
   a glance which half she was looking at, and the queue block — the one
   way to run several goals back-to-back — read as a footnote. The pass
   wraps each in its own `<section>` with an `h2` and the DESIGN.md Card
   tokens, and tags them `data-role="add-goal-section"` and
   `data-role="goals-list-section"` so the two halves of the page are
   named and testable.
2. **Save was not the primary action.** DESIGN.md reserves the brand
   gradient for the one main action in the shell; Save Goal rendered as
   a daisyUI `btn btn-primary`, the same shape and weight as Cancel beside
   it. Save Goal and Queue Selected Goals are now
   `btn-brand-gradient rounded-box px-4 py-2 w-full sm:w-auto`, full-width
   on a phone, and the empty-state Connect Integrations link gets the
   same treatment. One gradient Primary per card.
3. **Every panel used `mf-card`, which is undefined.** `assets/css/app.css`
   has no `.mf-card` rule, so the "Goal Metric" form and the "Queue
   Multiple Goals" block drew with no border or background. Replaced with
   the DESIGN.md Card spec (`bg-base-200 border border-neutral rounded-
   box`) bound to a single `@card` module attribute so every panel on
   this page uses the same tokens.

## What the page lost, and whether that is right

- The small `btn btn-primary` Save and the plain `btn btn-secondary`
  Queue button. Right to lose: DESIGN.md's Primary spec reserves the
  brand gradient for exactly those actions, and the old treatment made
  Save read as a secondary control.
- The `mf-card` class on both panels. Right to lose: it never resolved
  to any CSS rule, so nothing was drawing around those panels anyway;
  the DESIGN.md Card tokens actually render.
- The undecorated single column (no section headings, no clear boundary
  between "start one goal" and "queue several"). Right to lose: the two
  forms do different jobs, and splitting them with labelled sections
  makes that visible instead of implicit.

## What is kept verbatim

Every pre-existing `id` and `data-*`: `#goal-metric-form`,
`select[name='goal_metric_name']`, `input[name='goal_metric_names[]']`,
`data-role='save-goal'`, `data-role='cancel'`, `data-role='queue-goals'`,
and the `phx-change="select_goal"` / `phx-submit="save_goal"` /
`phx-submit="queue_goals"` / `phx-click="cancel"` bindings tests and spex
depend on. The two new attributes are the `data-role="add-goal-section"`
and `data-role="goals-list-section"` wrappers, both added so the two
parts of the page are testable (see
`test/metric_flow_web/live/correlation_live/goals_test.exs`, describe
"presents the add-goal form and the goals list as separate sections").
