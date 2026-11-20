# Evidence — onboarding-design-pass

Four full-page PNGs at 390px and 1440px of `/onboarding`, captured against
the seeded Anderson Retail Co. account (owner `client@example.com` from
`priv/repo/seeds.exs`, password `hello world!`):

| File            | Viewport  | What it shows |
|-----------------|-----------|---------------|
| before-390.png  | 390x844   | Pre-pass welcome on a phone. A single text block inside an undefined `rounded-xl` panel (`border-base-content/15`, `bg-base-200/40`), two look-alike actions (`bg-primary` "Connect your data" and a `border-base-content/20` "Open the app") — two primaries on one step, no stepper, no sense of what is done and what is next. |
| before-1440.png | 1440x900  | Pre-pass welcome on desktop. Same off-token borders (`base-content/15`, `base-content/20`), same `rounded-xl` and `rounded-lg` instead of `rounded-box`, same two competing actions side-by-side. |
| after-390.png   | 390x844   | Post-pass welcome on a phone. Three-step wizard header in the same style as `/app/onboarding/connect` — `#wizard-step-welcome` is marked `data-done="true"` with a success check, `#wizard-step-connect` is the current primary pill, `#wizard-step-dashboard` is the greyed next step. Card uses DESIGN.md's Card spec (`bg-base-200 border border-neutral rounded-box`). Exactly one primary action per step: the brand-gradient "Connect your data". The dashboard shortcut is a tertiary inline link. Stepper wraps (`flex-wrap`) and connector lines are `hidden sm:inline-block`, so no sideways scroll at 390. |
| after-1440.png  | 1440x900  | Post-pass welcome on desktop. Same stepper, same single-primary rule, same Card surface. Connector lines are `bg-neutral`, pill is `bg-primary`, dashboard shortcut sits in a `border-t border-neutral` footer. |

## Capture environment

- A phx.server from this worktree, launched under tmux with
  `PORT=4078 DATABASE_NAME=metric_flow_dev MIX_ENV=dev mix phx.server`
  against the shared seeded `metric_flow_dev` database. Hitting the
  default `:4070` would have screenshot the main dev server, which is a
  different checkout.
- agent-browser CLI (headless Chromium) for navigation and capture:
  `set viewport <w> <h>`, log in as `client@example.com`, then
  `open http://127.0.0.1:4078/onboarding`.
- For every shot the driver read back `location.pathname` and
  `liveSocket.isConnected()` — all four shots were on
  `/onboarding` with the LiveView socket connected.
- At 390 the driver also read `document.documentElement.scrollWidth`
  and `window.innerWidth`: both read 390 for the `after` shot,
  confirming no sideways scroll on a phone.
- The before shots were captured by copying the committed fix aside to
  `/tmp/onboarding_live-fix.ex`, running
  `git checkout HEAD -- lib/metric_flow_web/live/onboarding_live.ex`
  so Phoenix dev's code reloader re-rendered the pre-fix markup,
  shooting, then copying the fix back.
