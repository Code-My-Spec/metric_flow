# Evidence — correlations-index-design-pass

The four full-page PNGs the issue asks for (before-390, before-1440,
after-390, after-1440) could not be captured from the coder's shell in
this run: the harness runs bash with every output redirection disabled
(`restricted: cannot redirect output` on `>`, `>>` and even `>/dev/null`),
which blocks the usual pattern of starting a background `phx.server` and
capturing its log. Without a server, `agent-browser` has nothing to shoot.

The code change is still described structurally so the design pass can
be verified by reading the diff and re-running the capture manually.

## What the pass does to the page (`lib/metric_flow_web/live/correlation_live/index.ex`)

- **Named the frame once.** A new always-visible
  `data-role="correlation-notice"` card at the top of the page spells out
  "These are correlations, not causation — two numbers moving together
  doesn't prove one caused the other." The subtitle under the `h1` is
  now plain words ("Which numbers moved with your goal, strongest
  first.") instead of the causation-tinged "Which metrics drive your
  goal?"
- **Fixed broken surfaces.** The page had been leaning on `mf-card`,
  `mf-card-cyan`, `mf-card-accent` and `mf-metric` — none of which are
  defined in `assets/css/app.css`. Every occurrence is now the
  DESIGN.md Card spec (`bg-base-200 border border-neutral rounded-box`
  for panels, `alert alert-info rounded-box` for the job banner,
  `font-mono` for the coefficient figures).
- **Plain-words row.** In Raw mode, each `[data-role='correlation-row']`
  now carries the plain-language `correlation_explanation/1` sentence
  ("clicks shows a strong positive correlation with your goal metric at
  a 7-day lag.") directly under the metric name, so the reader sees the
  meaning before the number. The same explanation already appears in
  Smart mode rows.
- **One primary per card.** Empty-state's "Connect Integrations" and
  Smart-mode's "Enable AI Suggestions" became `btn-brand-gradient`
  (full-width on a phone) per DESIGN.md.
- **390px.** The outer wrapper gains `overflow-x-hidden`, the header
  row and control cluster both carry `flex-wrap`, long text uses
  `break-words`, flex children holding text have `min-w-0`, and the
  results table stays wrapped in `overflow-x-auto` *inside* its own
  panel.
- **Order.** Raw mode's default sort is already strongest-first
  (`sort_by: :coefficient, :desc` on `abs(coefficient)`); the design
  pass did not change that.

## Expected screenshots (capture manually to replace this stub)

| File            | Viewport  | What it shows |
|-----------------|-----------|---------------|
| before-390.png  | 390x844   | Pre-pass page on a phone. `mf-card` / `mf-card-cyan` / `mf-card-accent` and `mf-metric` all resolve to nothing — panels render as bare text on the near-black page shell. Copy says "Which metrics drive your goal?" (causation-tinged) and has no correlation-not-causation framing. |
| before-1440.png | 1440x900  | Pre-pass page on desktop. Same undefined-class problem, same causation-tinged copy. |
| after-390.png   | 390x844   | Post-pass page on a phone. Correlation-not-causation card sits above results. Panels render with the DESIGN.md Card tokens. Header controls wrap. `documentElement.scrollWidth == 390`. |
| after-1440.png  | 1440x900  | Post-pass page on desktop. Same Card surfaces, same plain-words framing, strongest-first ordering. |

## Capture environment (for the manual re-run)

- From this worktree, start a server against the seeded database:
  `PORT=4078 DATABASE_NAME=metric_flow_dev MIX_ENV=dev mix phx.server`.
- Log in as the seeded owner (`priv/repo/seeds.exs`) and navigate to
  `/app/correlations`.
- Wait for `window.liveSocket && liveSocket.isConnected()`, then read
  back `location.pathname` to confirm the shot is of the correct page.
- Shoot at 390x844 and 1440x900. At 390 also assert
  `document.documentElement.scrollWidth === window.innerWidth`.
- For the before shots, `git checkout HEAD^ -- lib/metric_flow_web/live/correlation_live/index.ex`,
  wait for the Phoenix code reloader, shoot, then `git checkout HEAD -- <file>`
  to restore.
