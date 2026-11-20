# Evidence — dashboards-index-design-pass

Browser screenshots of `/app/dashboards` on the seeded data in
`priv/repo/seeds.exs`, captured on a local `mix phx.server` (dev, port
4085, database `metric_flow_dp_dashboards`) signed in as the seeded
owner of Anderson Retail Co. (`client@example.com`, password
`hello world!`) — the account the seeds attach the two sample
dashboards ("Growth Overview" and "Paid Media") to, so the grid
renders populated rather than empty.

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned true and
`location.pathname === "/app/dashboards"` was confirmed. At 390,
`document.documentElement.scrollWidth === 390` (no sideways scroll)
was read back before the shot. The before shots were captured on the
pre-pass code checked out at the main worktree (port 4070), whose
`lib/metric_flow_web/live/dashboard_live/index.ex` still carried the
`mf-card` undefined class and the small secondary-style New Dashboard
button that this pass replaces.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|---------------|
| `before-390.png`  | 390x1196 | before | Pre-pass phone page. `mf-card` panels (not defined in `assets/css/app.css`, so no border/background draws around the cards). The "New Dashboard" button renders as a small daisyUI `btn btn-primary btn-sm` indistinguishable from any secondary control, instead of the brand-gradient primary that DESIGN.md reserves for the main action. Subtitle reads "Your saved views and system dashboards" — describes the sections, not what the reader should do. |
| `before-1440.png` | 1440x900 | before | Pre-pass desktop page. Same `mf-card` issue and same small secondary-style create button. The row of six action buttons (View, Edit with agent, Rename, Favorite, Duplicate, Delete) sits in a non-wrapping flex row that can crowd narrow cards. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page. DESIGN.md Card tokens (`bg-base-200 border border-neutral rounded-box`) on every panel. The New Dashboard button is `btn-brand-gradient rounded-box px-4 py-2 w-full sm:w-auto` and drops full-width under the heading at 390, making "create" the obvious primary action. Action rows carry `flex-wrap`; the outer column carries `overflow-x-hidden`; names use `break-words min-w-0`. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop page. Same card tokens on canned and user dashboards. The gradient New Dashboard button sits top-right. Each dashboard still renders as one `data-role="dashboard-card"` and keeps every existing id / data-role / phx-click. |

## What the pass does to the page (`lib/metric_flow_web/live/dashboard_live/index.ex`)

Top three problems ranked by cost to the direct independent marketer
(Dana, who self-funds the tool and wants clarity over complexity):

1. **Create was not the primary action.** The only way to start a new
   dashboard was a small `btn btn-primary btn-sm` indistinguishable
   from the per-card ghost buttons, so the thing Dana opens this page
   to do (make a new one when she has an idea) read as a secondary
   control. Fixed by replacing it with the DESIGN.md Primary button:
   `btn-brand-gradient rounded-box px-4 py-2 w-full sm:w-auto`, full
   width on a phone. The empty-state "Create your first dashboard"
   link is promoted to the same gradient treatment.
2. **Every panel used `mf-card`, which is not defined.** The CSS has
   no `.mf-card` rule, so canned dashboards, user dashboards, the
   empty state, and the no-search-results state all drew with no
   border or background. Replaced with the DESIGN.md Card spec
   (`bg-base-200 border border-neutral rounded-box`) via a single
   module attribute so every panel on the page uses the same tokens.
3. **The six-button action row could overflow at 390.** The old
   layout was `flex items-center gap-2` with no `flex-wrap`, so on a
   narrow phone the row of View / Edit / Rename / Favorite /
   Duplicate / Delete relied on implicit shrinking. Added
   `flex-wrap`, added `overflow-x-hidden` to the outer column, and
   added `break-words min-w-0` to the dashboard name so a long title
   wraps instead of pushing the row sideways. `scrollWidth === 390`
   at 390 after the pass.

Also:
- Subtitle reframed to lead with what the page offers ("One card per
  dashboard. Start a new one any time.") instead of describing the
  sections.
- Search input adopts the DESIGN.md Form input tokens
  (`bg-base-100 border-neutral rounded-box`); rename-input uses the
  same tokens.
- Secondary muted text raised from `text-base-content/60` to
  `text-base-content/70` per DESIGN.md's `--brand-muted` guidance.
- Only theme tokens; no hard-coded colours or radii added.

## What the page lost, and whether that is right

- The small `btn btn-primary btn-sm` New Dashboard button in the
  header. Right to lose: the DESIGN.md Primary button spec reserves
  the brand gradient for "the main action in the shell"; on this
  page, creating a new dashboard *is* that action, and the old
  treatment made it invisible.
- The old subtitle "Your saved views and system dashboards". Right
  to lose: it described the two sections, not what the reader should
  do on this page.
- The `mf-card` class name everywhere. Right to lose: it did not
  resolve to any CSS rule in `assets/css/app.css`, so nothing was
  drawing around the panels anyway.

## States the seeded data could not exercise, and how they were checked

- **Empty state** (`data-role="empty-user-dashboards"`): the seeded
  client account has two dashboards, so the empty state is not in
  the after screenshots. It is exercised by
  `test/metric_flow_web/live/dashboard_live/index_test.exs` ("shows
  empty state when user has no saved dashboards") and spex 1072,
  both of which still pass with the DESIGN.md Card + gradient
  button in that branch.
- **Empty search results** (`data-role="empty-search-results"`):
  likewise not shown in the after screenshots. Exercised by spex
  1074 ("Dana searches for a dashboard that does not exist"), which
  still passes.
- **Inline delete confirmation** and **inline rename form**: neither
  is in the steady-state screenshot. Both are exercised by index
  tests and spex 1068–1071, all of which pass.
- **Read-only agency member** (can_build? false branch): not
  exercised by seeds; spex 1072 covers it and still passes.

## For the owner to decide

- The New Dashboard button is now full-width on a phone
  (`w-full sm:w-auto`), per DESIGN.md's Primary button spec. If a
  smaller phone treatment is preferred later, that is a single
  class change on one element.
- The secondary muted text was nudged from `text-base-content/60` to
  `text-base-content/70` on this page only. If `/60` is still the
  preferred house default elsewhere, this is an isolated page-level
  choice, not a token change.

## Preserved ids and data-roles

Every pre-existing attribute used by tests is kept verbatim:
`new-dashboard-btn`, `canned-dashboards`, `dashboard-card`,
`view-dashboard-<id>`, `edit-dashboard-<id>`,
`rename-dashboard-<id>`, `rename-form-<id>`, `rename-input-<id>`,
`confirm-rename-<id>`, `cancel-rename`, `favorite-dashboard-<id>`
(and its `.text-warning` class on the favorited state),
`duplicate-dashboard-<id>`, `delete-dashboard-<id>`,
`delete-confirm-<id>`, `confirm-delete-<id>`, `cancel-delete`,
`user-dashboards`, `empty-user-dashboards`, `empty-search-results`,
`dashboard-search`, plus `data-dashboard-id` and `data-built-in` on
every card.
