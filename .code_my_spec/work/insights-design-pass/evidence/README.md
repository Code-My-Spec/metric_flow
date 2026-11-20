# Evidence — insights-design-pass

Browser screenshots of `/app/insights` on the seeded data in
`priv/repo/seeds.exs`, captured on a local `mix phx.server` (dev, port
4082, database `metric_flow_insights_dp`) logged in as the seeded
owner of Anderson Retail Co. (`client@example.com`, password
`hello world!`) — the retail client that the seeds attach the
correlation job, three correlation results, and the AI insights to.

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned true and
`location.pathname === "/app/insights"` was confirmed. At 390,
`document.documentElement.scrollWidth === 390` (no sideways scroll).
The before shots were captured by checking out the pre-pass file
(`git checkout HEAD~1 -- lib/metric_flow_web/live/ai_live/insights.ex`),
letting Phoenix code-reload, shooting, then restoring HEAD.

## Files

| File              | Viewport   | State  | What it shows |
|-------------------|------------|--------|---------------|
| `before-390.png`  | 390x844    | before | Pre-pass phone page. `mf-card` panels (an undefined class, so nothing draws around them). No verified/hypothesis labelling. Subtitle reads "Actionable recommendations generated from your correlation analysis" — describes the data source, not what the reader should do. |
| `before-1440.png` | 1440x900   | before | Pre-pass desktop page. Same `mf-card` panels and same missing verified/hypothesis labelling; badges stack right of the summary in a row that can feel crowded. |
| `after-390.png`   | 390x1071   | after  | Post-pass phone page. DESIGN.md Card tokens (`bg-base-200 border border-neutral rounded-box`) on every panel. Header actions wrap under the heading at 390 (`flex-wrap gap-3`); nothing scrolls sideways (`scrollWidth === 390`). Each insight carries `data-role="insight-status-badge"` tagged `verified` or `hypothesis`, shown first in the badge row. Subtitle leads with what the page does: "Newest first. Each one is marked Verified or Hypothesis". |
| `after-1440.png`  | 1440x900   | after  | Post-pass desktop page. Same card tokens, same status badges, newest insights first. Free-user paywall branch (not seeded here, but verified in tests) now renders inside `Layouts.app` so the shell stays visible. |

## What the pass does to the page (`lib/metric_flow_web/live/ai_live/insights.ex`)

- Replaces every `mf-card` (not defined in `assets/css/app.css`) with the
  DESIGN.md Card spec: `bg-base-200 border border-neutral rounded-box`.
- Adds `data-role="insight-status-badge"` on each card, with
  `data-insight-status="verified"` for `Insight.high_confidence?/1`
  (confidence >= 0.7) and `"hypothesis"` otherwise. The badge sits in
  the first row so a reader sees at a glance which recommendations are
  safe to act on and which are leads to watch.
- Reframes the subtitle in plain words: "Newest first. Each one is
  marked Verified or Hypothesis" — leading with what the page offers
  the referred-customer persona (non-technical operator who wants to
  know which numbers to trust).
- Wraps the free-user paywall branch in `Layouts.app` so the shell,
  sidebar, and account identity stay visible; keeps the shared
  `paywall_modal` component and all of its `data-role` hooks
  (`paywall`, `upgrade-modal`, `paywall-cta`) intact.
- Adds `flex-wrap`, `min-w-0`, `break-words`, and `overflow-x-hidden`
  on the outer column so nothing scrolls sideways at 390.
- Preserves every pre-existing `id` and `data-*` attribute used by
  tests (type-filter, no-insights-state, no-filter-results-state,
  clear-filter, insights-list, insight-card, insight-summary,
  insight-type-badge, insight-confidence-badge, insight-content,
  insight-correlation-ref, insight-generated-at, delete-insight,
  ai-feedback-section, insight-feedback, feedback-helper-text,
  feedback-helpful, feedback-not-helpful, feedback-confirmation,
  ai-personalization-note, clear-all-insights, generate-insights).

No hard-coded colours or radii; theme tokens only.
