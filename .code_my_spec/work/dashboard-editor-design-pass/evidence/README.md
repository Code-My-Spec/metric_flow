# Evidence — dashboard-editor-design-pass

Browser screenshots of `/app/dashboards/new` on the seeded data in
`priv/repo/seeds.exs`, captured on local `mix phx.server` instances
signed in as the seeded owner of "Anderson Retail Co."
(`client@example.com`, password `hello world!`). The before shots came
from the pre-pass main worktree (port 4070, serving `dd0d496c` --
the handed-in editor.ex) and the after shots came from this worktree's
own server (port 4085, same `metric_flow_dev` database, serving this
pass's edits).

For each width the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned true, and
`location.pathname === "/app/dashboards/new"` and
`document.documentElement.scrollWidth` were read back before the shot.
At 390, `scrollWidth === 390` on both the before and after pages
(the editor's main column already carried `overflow-x-hidden` via the
shell, so the pre-pass page also fit a phone horizontally -- the fault
the pass fixes is one of structure and tokens, not a sideways scroll).
At 1440, `scrollWidth === 1440` on both.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|---------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page. Panels (`Build with AI`, `filter-control`, empty canvas) use the undefined `mf-card` class, so they render with no border or background against the page. The Save button is a small daisyUI `btn btn-primary` the same size and weight as the ghost Cancel link beside it, instead of the brand-gradient primary that DESIGN.md reserves for the main action. The Build-with-AI card, filter row and canvas stack with no visible separation between "controls" and "preview". |
| `before-1440.png` | 1440x900 | before | Pre-pass desktop page. Same `mf-card` and `btn btn-primary` issues. The page content runs the full width of the main column, so the save/cancel header, the chat panel, the filter row and the empty canvas blur into a single column with no section break. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page. Panels use the DESIGN.md Card spec (`bg-base-200 border border-neutral rounded-box`) so every control reads as a card. Save is the `btn-brand-gradient rounded-box px-4 py-2 w-full sm:w-auto` primary and goes full width on the phone; Cancel is the DESIGN.md Secondary button. A `data-role="editor-controls"` section (Controls heading + name, chat, versions, date range and platform panels) is split from a `data-role="editor-preview"` section (Preview heading + canvas) by a `border-t border-neutral` divider, so a 390-wide reader sees two visibly separate areas. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop page. The outer column is capped at `max-w-5xl mx-auto overflow-x-hidden` so the editor stops running edge-to-edge on a desktop; the Controls / Preview split and all of DESIGN.md's Card tokens read the same on desktop as on phone. |

## What the pass does to the page (`lib/metric_flow_web/live/dashboard_live/editor.ex`)

Top three problems ranked by cost to Dana (the direct independent
marketer who self-funds the tool and prizes "Clarity > Complexity"):

1. **Preview was not visibly separate from the controls.** The Build-
   with-AI chat, Versions list, date range, platform filter and the
   canvas all stacked in one column with no heading, divider or token
   that said "this half is what you edit; this half is what gets
   built." On a phone, Dana could not tell at a glance which card she
   was looking at. Fixed by wrapping the editing inputs in a
   `<section data-role="editor-controls">` with a "Controls" heading
   and the canvas in a `<section data-role="editor-preview">` with a
   "Preview" heading separated by a `border-t border-neutral`
   divider, so the two roles are obvious at 390 and at 1440.
2. **Save was not the primary action.** The one thing this page is for
   -- persisting a dashboard Dana just built -- rendered as a small
   `btn btn-primary` the same shape and weight as the Cancel ghost
   link next to it. Replaced with the DESIGN.md Primary button
   (`btn-brand-gradient rounded-box px-4 py-2 w-full sm:w-auto`) so
   Save is the obvious main action, and goes full width on a phone.
   The chat composer's Send button got the same gradient treatment for
   the same reason -- it's the one way to push a turn to the agent.
   Cancel became the DESIGN.md Secondary button (`rounded-box border
   border-neutral bg-base-200 ... hover:bg-base-300`).
3. **Every panel used `mf-card`, which is not defined.** The CSS
   (`assets/css/app.css`) has no `.mf-card` rule, so the Build-with-
   AI panel, the Versions panel, the `filter-control` panel and the
   empty-canvas tile all drew with no border or background against
   the page. Replaced with the DESIGN.md Card spec
   (`bg-base-200 border border-neutral rounded-box`) on every panel
   this page owns, and the filter control picked up `flex-wrap` and
   the date-range select the Form tokens (`bg-base-100 border-neutral
   rounded-box`). The textarea in the chat composer took the same
   Form input tokens.

Also:
- The outer column carries `max-w-5xl mx-auto overflow-x-hidden` so
  on desktop the editor stops running edge-to-edge and on a phone
  nothing can push the page sideways even as narrow chat and canvas
  content wraps.
- Header `flex` row became `flex-wrap items-center gap-3` so the title
  and action cluster drop cleanly to two lines at 390 rather than
  relying on shrinking.
- Chat message bubbles use `rounded-box` and `break-words` so long
  assistant replies wrap instead of forcing a sideways scroll.
- Chat form's flex row got `flex-wrap` so the Send button drops under
  the textarea at 390 rather than squeezing it.
- Only theme tokens; no hard-coded colours or radii added; the
  `btn-brand-gradient`, `rounded-box` and base-content/muted tokens
  are the same ones already used by the Primary and Card patterns
  elsewhere in the shell.

## What the page lost, and whether that is right

- The small `btn btn-primary` Save Dashboard button. Right to lose:
  DESIGN.md's Primary button spec reserves the brand gradient for
  "the main action in the shell"; on this page Save *is* that action,
  and the old treatment made it indistinguishable from Cancel.
- The small `btn btn-primary btn-sm` Send button on the chat composer.
  Right to lose: pushing a turn to the agent is the composer's one
  action; it earns the same gradient treatment Send gets everywhere
  else in the shell.
- The `mf-card` class name on every panel. Right to lose: it never
  resolved to any CSS rule, so nothing was drawing around those
  panels anyway -- the DESIGN.md Card tokens actually render.
- The undecorated single column. Right to lose: the editor was always
  two jobs (edit the thing / see the thing); splitting them with a
  divider and labelled sections makes that visible instead of
  implicit.

## States the seeded data could not exercise, and how they were checked

- **Versions list** (`data-role="dashboard-version-list"`): only shown
  for an existing dashboard whose chat has produced at least one
  paper_trail version. The seeded fixture dashboards are static, so
  this panel is not in the after screenshots. It is exercised by
  `test/metric_flow_web/live/dashboard_live/editor_test.exs` (the
  refine-through-chat and restore spex tests), all of which still
  pass under the new Card tokens and markup.
- **Dashboard-chat-error** (`data-role="dashboard-chat-error"`): only
  shown when the agent returns an error. Covered by the existing
  "no metrics available" and model-error spex tests.
- **Visualization canvas with widgets**: shown only after a chat turn
  succeeds. Covered by the editor_test's "send_dashboard_chat with
  metrics available" and spex 1062.
- **Platform filter highlighting**: covered by the existing editor
  test "a dashboard saved with a platform filter highlights that
  platform" (issue f50d37e9), which still passes -- the pass did not
  touch `MetricFlowWeb.DashboardLive.Components.platform_filter/1`.

## For the owner to decide

- The Save Dashboard button and the chat Send button are both the
  brand-gradient Primary now, with Save at the top of the page and
  Send inside the chat panel. DESIGN.md says "one primary button per
  form or card" -- Save sits in the page's header row rather than
  inside the chat form, so the composer's own form still has exactly
  one primary. If the owner prefers only Save to be gradient and the
  chat Send to be secondary, that is a one-class flip on the Send
  button.
- The Controls / Preview heading labels are literal English ("Controls"
  and "Preview"). The alternative is to leave the sections implicit
  with only a divider -- reads cleaner on desktop, less obvious on a
  phone. The pass chose explicit labels because the persona is a
  solo marketer skimming on a phone between other jobs.

## Preserved ids and data-roles

Every pre-existing attribute used by tests is kept verbatim:
`save-dashboard-btn`, `dashboard-name-input`, `dashboard-chat-panel`,
`dashboard-chat-messages`, `dashboard-chat-message`,
`dashboard-chat-form`, `dashboard-chat-input`,
`dashboard-chat-send-btn`, `dashboard-chat-error`,
`dashboard-version-list`, `dashboard-version`, `restore-version`,
`filter-control`, `visualization-canvas`, `empty-canvas`, and the
`id="dashboard-date-range"` / `id="visualization-canvas"` ids the
LiveView and its tests rely on. The `data-role="editor-controls"`
and `data-role="editor-preview"` roles are new, added by this pass
so the Controls / Preview split is testable.
