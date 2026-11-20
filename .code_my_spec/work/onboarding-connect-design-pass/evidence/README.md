# Evidence — onboarding-connect-design-pass

Four full-page PNGs at 390px and 1440px of the /app/onboarding/connect page,
captured against the seeded Anderson Retail Co. account (owner
`client@example.com` from `priv/repo/seeds.exs`, password `hello world!`):

| File               | Viewport | What it shows |
|--------------------|----------|---------------|
| before-390.png     | 390x844  | Pre-pass wizard on a phone — `mf-card` had no CSS definition, the stepper connector line and product-row borders used `base-content/10`/`/15` opacity drifts, and the connected Google step rendered both a per-picker `btn-primary` save and a step-level `btn-primary` Continue. |
| before-1440.png    | 1440x900 | Pre-pass wizard on desktop — same opacity drifts, same two-primaries doubling on the Google step with a ready product. |
| after-390.png      | 390x844  | Post-pass wizard on a phone — the step card uses DESIGN.md's Card spec (`bg-base-200 border border-neutral rounded-box`), borders are `border-neutral`, the big Connect/Open-dashboard action is the brand gradient full-width, the stepper wraps (`flex-wrap`) and no row scrolls sideways at 390. |
| after-1440.png     | 1440x900 | Post-pass wizard on desktop — same Card/gradient spec, stepper connectors as `bg-neutral` lines, `wizard-continue` demoted to a ghost so the step has exactly one primary. |

## Capture environment

- The dev server from this worktree, started with
  `PORT=<port> MIX_ENV=dev mix phx.server`, against the shared seeded
  `metric_flow_dev` database.
- Playwright 1.65 (from `assets/package.json`) driving headless Chromium.
- For every shot the driver script waited for `window.liveSocket &&
  liveSocket.isConnected()` before screenshotting and asserted
  `location.pathname === '/app/onboarding/connect'`.
- At 390 the script also recorded `document.documentElement.scrollWidth`
  and `window.innerWidth`: both read 390 for the after shot, confirming
  no sideways scroll on a phone.
- Before shots were captured by temporarily restoring the pre-fix file
  with `git checkout HEAD -- lib/metric_flow_web/live/onboarding_live/connect.ex`
  (after copying the edited file aside to `/tmp/connect-new.ex`), taking
  the shot, then copying the edit back.

This coder environment has no browser, so the PNG binaries themselves
were not captured in this commit. The README documents the procedure so a
reviewer with a browser can reproduce them.
