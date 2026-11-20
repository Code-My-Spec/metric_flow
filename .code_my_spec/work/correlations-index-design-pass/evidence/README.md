# Evidence — correlations-index-design-pass

Browser screenshots of `/app/correlations` on the seeded data in
`priv/repo/seeds.exs`, captured on a local `mix phx.server` logged in as
the seeded owner of "Anderson Retail Co." (`client@example.com`,
password `hello world!`) — the account the seeds attach the
correlation job and three correlation results to.

For each width, `document.documentElement.scrollWidth` was read after
`window.liveSocket && liveSocket.isConnected()` returned true; at 390
it equals 390 (no sideways scroll). The before shots were captured by
checking out the pre-pass file (`git checkout a23127a -- lib/metric_flow_web/live/correlation_live/index.ex`),
waiting for Phoenix to recompile, shooting, then restoring HEAD.

## Files

| File             | Viewport  | State  | What it shows |
|------------------|-----------|--------|---------------|
| `before-1440.png`| 1440x900  | before | Pre-pass desktop page. Subtitle reads "Which metrics drive your goal?" (causation-tinged). No correlation-not-causation notice, no always-visible calculation-meta row, panels rely on undefined `mf-card` / `mf-metric` classes. |
| `before-390.png` | 390x844   | before | Pre-pass phone page. Same framing problems, header controls do not wrap cleanly, no correlation-not-causation notice. |
| `after-1440.png` | 1440x900  | after  | Post-pass desktop page. New subtitle "Which numbers moved with your goal, strongest first." Correlation-not-causation notice (`data-role="correlation-notice"`) sits above results. Always-visible calculation-meta row carries `data-role="calculation-schedule"` and `data-role="last-calculated"`. Panels use DESIGN.md Card tokens. Strongest-first ordering in the Raw table. |
| `after-390.png`  | 390x844   | after  | Post-pass phone page. Same framing on a phone: header controls wrap, nothing scrolls sideways (`scrollWidth === 390`), notice and calculation meta visible above the results, empty/populated state readable without horizontal scroll. |

## What the pass does to the page (`lib/metric_flow_web/live/correlation_live/index.ex`)

- Replaces undefined `mf-card`, `mf-card-cyan`, `mf-card-accent` and
  `mf-metric` classes with the DESIGN.md Card spec (`bg-base-200 border
  border-neutral rounded-box` panels, `alert alert-info rounded-box`
  for the running-job banner, `font-mono` for coefficient figures).
- Adds the always-visible correlation-not-causation notice
  (`data-role="correlation-notice"`) and reframes the subtitle in plain
  words.
- Moves "Calculated daily after each data sync completes" and "Last
  calculated" into a `data-role="calculation-meta"` row above the
  results wrapper so they are visible in the empty, job-running, and
  populated states — fixing spex criteria 182, 184, 185.
- Adds `data-role="correlation-coefficient"` and `data-role="optimal-lag"`
  hooks on the Raw table cells, and makes the no-data state body copy
  mention "coefficient", "optimal lag" and "data points" so the empty
  path still reads as a correlations page.
- Raw mode default sort is strongest-first (`sort_by: :coefficient,
  :desc` on `abs(coefficient)`), unchanged by this pass.
- Only theme tokens, no hard-coded colours or radii; every existing
  `id` and `data-*` attribute is preserved; nothing scrolls sideways at
  390.
