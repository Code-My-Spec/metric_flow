# Evidence — integration-connect-design-pass

Four full-page PNGs of `/app/integrations/connect/google_ads` captured
from this worktree's own dev server against the seeded Anderson Retail
Co. account (owner `client@example.com` from `priv/repo/seeds.exs`,
password `hello world!`). The per-provider detail view is the right
view to compare: it carries the new `data-role="connect-stepper"` the
pass adds (step 1 of 2, "Choose provider" current, "Choose accounts"
upcoming), and it draws the primary action the pass promotes to the
brand gradient, so both the structural and the token changes are
visible in one frame at each width.

| File              | Viewport | Full page size   | State  | What it shows |
|-------------------|----------|------------------|--------|---------------|
| `before-390.png`  | 390x844  | 390 x 844        | before | Pre-pass phone page. No stepper. Per-provider card drawn with `mf-card` (an undefined class — no border, no background, just floating text on the page shell). Not-connected badge, platform description, a daisyUI `btn btn-primary` "Connect Google Ads" with the same weight as the ghost "Back to integrations" link below it. |
| `before-1440.png` | 1440x900 | 1440 x 900       | before | Same pre-pass markup on desktop, same lack of structure: no stepper, invisible card chrome, and the primary action sits as a flat daisyUI primary button, not the Anderson BI gradient. |
| `after-390.png`   | 390x844  | 390 x 844        | after  | Post-pass phone page. The `data-role="connect-stepper"` row sits above the card as two chips ("1 Choose provider" with `aria-current="step"`, "2 Choose accounts" muted). The card is drawn with the DESIGN.md Card tokens (`bg-base-200 border border-neutral rounded-box`), the Not-connected badge still reads, and the primary action is a full-width `btn-brand-gradient rounded-box` "Connect Google Ads". `document.documentElement.scrollWidth === 390` was read back before the shot. |
| `after-1440.png`  | 1440x900 | 1440 x 900       | after  | Same post-pass markup on desktop: stepper, token-driven card, gradient primary. The max-w-4xl column centres and the gradient button sits content-sized. |

## Capture environment

- Dev server started from this worktree with
  `PORT=4087 DATABASE_NAME=metric_flow_dev MIX_ENV=dev sops exec-env
  envs/dev.enc.env mix phx.server`, against the seeded `metric_flow_dev`
  database. The worktree's own tunnel gating (`main_copy?/0` in
  `lib/metric_flow_web/application.ex`) kept the Cloudflare tunnel
  disabled so the beam stayed on `127.0.0.1:4087`.
- `agent-browser` (headless Chromium) drove the login flow (filled
  `client@example.com` / `hello world!` and submitted), then navigated
  to `/app/integrations/connect/google_ads`. Before each screenshot the
  driver read back `window.liveSocket && liveSocket.isConnected()` (true
  both times), `location.pathname` (`/app/integrations/connect/google_ads`
  both times), and `document.documentElement.scrollWidth` (390 at the
  390 viewport, 1440 at the 1440 viewport).
- The before shots were taken after replacing
  `lib/metric_flow_web/live/integration_live/connect.ex` with the
  pre-pass version at commit `47e8bdab` (the issue as handed in), letting
  Phoenix live-reload re-render the old markup, and reading back
  `!!document.querySelector('.mf-card')` to confirm the pre-pass markup
  was on screen (true). The file was restored to HEAD before the final
  commit and before the after shots (which read `.mf-card` → false).

## What the pass does to the page (`lib/metric_flow_web/live/integration_live/connect.ex`)

Ranked problems for Jordan, the referred-client persona
(`.code_my_spec/personas/agency-client-referred-customer/summary.md`),
who opens a reconnect link from the agency's dashboard and needs to
finish a connection on a phone:

1. **The ordered path was invisible.** Picking a provider, then its
   accounts, then (for Google Business) its locations was three
   different URLs with no "where am I" indicator. Jordan could not tell
   at a glance that the step they were on was 1 of 2, 2 of 2 or 2 of 3.
   Added a visible `data-role="connect-stepper"` ordered list above
   every per-provider view, with `data-step="provider" | "accounts" |
   "locations"`, `data-current` and `data-done` attributes and
   `aria-current="step"` on the current one, so Provider → Accounts →
   Locations reads as one named path at 390 and 1440. The Google
   Business flow renders all three steps; every other provider renders
   two.
2. **Hard-coded Tailwind colours and non-token radii.** DESIGN.md
   forbids hard-coded colours and radii, but the YouTube channel
   selector used `border-amber-300 bg-amber-50 text-amber-950` for its
   revenue warning, `text-red-600` for its selection error, `rounded-xl`
   on the outer card and `rounded-lg` on each channel row; the GBP
   account selector drew its two error panels with `rounded-lg border
   border-amber-300` and `rounded-md ... hover:bg-amber-100` reconnect
   links; the account selector drew every account row with plain
   `rounded` on `bg-base-200`; three views used `mf-card`, a class with
   no CSS rule anywhere in the app. Replaced each hard-coded amber or
   red surface with `alert alert-warning` / `alert alert-error` on
   `rounded-box`; replaced every non-token radius with `rounded-box`;
   replaced each `mf-card` with the DESIGN.md Card spec
   (`bg-base-200 border border-neutral rounded-box`).
3. **The main action never rendered as the main action.** Save channels
   was a custom `bg-primary` rectangle; Save and continue on GBP
   accounts was `btn btn-primary btn-sm`; Save Selection on the
   accounts step was `btn btn-primary w-full`; the OAuth connect anchor
   was `btn btn-primary`; every one of them read the same weight as
   their Back / Cancel neighbours. DESIGN.md reserves
   `btn-brand-gradient rounded-box` for "the main action in the shell",
   so each step's one commit action is now that class, full-width on a
   phone (`w-full`), and the Back / Cancel neighbours are the DESIGN.md
   Secondary (`rounded-box border border-neutral bg-base-200 ... hover:
   bg-base-300`).

## Structural checks

- `MIX_ENV=test mix test test/metric_flow_web/live/integration_live/connect_test.exs`
  passes 16 tests, including the four new assertions under
  `describe "design pass: provider -> accounts -> locations reads as one
  ordered path"`: the provider-detail view renders `[data-role='connect-
  stepper']` with Provider as the current step; the accounts-step view
  renders the stepper with Provider marked done and Accounts marked
  current; the primary save action on the accounts step carries the
  `btn-brand-gradient` class the DESIGN.md Primary spec names; and the
  source file no longer contains any of `bg-amber-50`, `border-amber-300`,
  `text-amber-950`, `hover:bg-amber-100`, `text-red-600`, `rounded-xl`,
  `rounded-lg`, `rounded-md`, or `mf-card`.
- The same four assertions fail against the pre-pass file (the issue as
  handed in at commit `47e8bdab`), confirmed by stashing the connect.ex
  edit and running the describe: four failures, each matching one of
  the three ranked problems.
- The full suite — `MIX_ENV=test mix test` — is 3156 passed, 0 failures,
  and every spex folder that keys off this page passes under `mix spex`
  (11, 12, 13, 17, 43, 44, 56).

## Sample data could not show

A reseller-branded header for the referred-client flow is a seeded
agency's white-label config (agency account `type: :agency`). The
seeded client@example.com is the owner of a client account that
reports to "Anderson the Fish" but the dev seeds don't attach a
white-label logo override, so the shell draws the default Anderson BI
logo in these shots. That matches every other seeded capture in
`.code_my_spec/work/*-design-pass/evidence/` for this persona.

## For the owner to decide

The stepper for a non-Google-Business provider renders two steps
(Provider → Accounts). For `google_business` the accounts step is
actually the second of three, since after selecting GMB *accounts*
(step 2, `view_mode = :gbp_accounts`) Jordan selects *locations*
(step 3, `view_mode = :accounts` for GBP). The stepper labels reflect
that split: `Choose accounts` for `:gbp_accounts`, `Choose locations`
for `:accounts` on `google_business`. If the owner wants the GBP flow
rebranded to a single "Choose what to sync" step, the labels live in
`connect_steps/2` at the bottom of the render block.
