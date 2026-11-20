# Evidence — onboarding-connect-design-pass

Four full-page PNGs at 390px and 1440px of the /app/onboarding/connect
page, captured against the seeded Anderson Retail Co. account (owner
`client@example.com` from `priv/repo/seeds.exs`, password
`hello world!`):

| File            | Viewport  | What it shows |
|-----------------|-----------|---------------|
| before-390.png  | 390x844   | Pre-pass wizard on a phone. The step `<section>` leans on `mf-card`, which has no CSS definition in the project, so the panel renders as bare text on the near-black page shell. Borders drift from DESIGN.md tokens (`base-content/10`, `/15`), the Connect-Google action is a solid `btn btn-primary btn-lg` not the brand gradient, and the step-level Continue button toggles to `btn-primary` whenever any product on the step is ready — two primaries on one step. |
| before-1440.png | 1440x900  | Pre-pass wizard on desktop. Same `mf-card`-with-no-definition problem and same two-primaries-when-ready doubling; stepper connector lines drawn with `bg-base-content/15`. |
| after-390.png   | 390x844   | Post-pass wizard on a phone. The step and done sections use DESIGN.md's Card spec (`bg-base-200 border border-neutral rounded-box`). Connect-Google is the brand-gradient primary, full-width. The stepper wraps (`flex-wrap`) with `hidden sm:inline-block` connectors so the five pills fit without sideways scroll. `wizard-continue` is a ghost — exactly one primary per step. |
| after-1440.png  | 1440x900  | Post-pass wizard on desktop. Same Card surface, same single-primary rule. Stepper connector lines are `bg-neutral` (theme-token), footer divider is `border-neutral`. |

## Capture environment

- A phx.server from this worktree, launched with
  `PORT=4078 DATABASE_NAME=metric_flow_dev MIX_ENV=dev mix phx.server`
  against the shared seeded `metric_flow_dev` database. Hitting the
  default :4070 would have screenshot the main dev server (CWD
  `/Users/johndavenport/cms-dogfood/metric_flow-prod`), which is a
  different checkout — verified by `lsof -p ...` on the port holder.
- agent-browser CLI (headless Chromium) for navigation and capture:
  `set viewport <w> <h>`, log in as `client@example.com`, then
  `open http://127.0.0.1:4078/app/onboarding/connect`.
- For every shot the driver waited on
  `window.liveSocket && liveSocket.isConnected()` before screenshotting
  and read back `location.pathname` — all four shots were on
  `/app/onboarding/connect`.
- At 390 the driver also read `document.documentElement.scrollWidth`
  and `window.innerWidth`: both read 390 for the `after` shot,
  confirming no sideways scroll on a phone.
- The before shots were captured by copying the committed fix aside to
  `/tmp/connect-fix.ex`, running
  `git checkout HEAD^ -- lib/metric_flow_web/live/onboarding_live/connect.ex`
  so Phoenix dev's code reloader re-rendered the pre-fix markup,
  shooting, then copying the fix back and running
  `git reset HEAD -- <file>` so the index matches HEAD again.
