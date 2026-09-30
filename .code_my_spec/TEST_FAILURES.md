# What is still red, and why

`mix spex` **27 failing** (this copy, 2026-09-30). `mix test` is fully green
(2919 passed, 10 excluded). Every failure below is a real, known gap in an
unbuilt or partly-built feature — none are wiring or drift.

## Agency white-label configuration (story 30) — 8 spex

`criterion_250` through `criterion_257`. No `#white-label-form` exists yet on
the agency settings page — logo upload, color scheme, custom subdomain + DNS
verification, preview-before-save, reset-to-default, and the
no-Anderson-branding check all wait on that form.

## Client sees white-labeled interface (story 31) — 1 spex

`criterion_262` — originator branding persisting across pages depends on the
same white-label form above.

## Agency team auto-enrollment (story 4) — 6 spex

`criterion_23` through `criterion_28`. `AutoEnrollmentRule` exists as a
schema and repository function; the settings-page LiveView form
(`#auto-enrollment-form`) does not.

## Feature gate / paywall for free users (story 45) — 3 spex

`criterion_497`, `498`, `500` — no paywall modal/CTA UI exists yet, and an
agency customer whose subscription is flagged-but-still-subscribed currently
loses AI access instead of keeping it.

## Agency customer billing edge cases (story 49) — 6 spex

`criterion_431`, `432`, `482`, `485`, `487`, `493` — webhook routing/sync for
agency-billed customers, invite-link signup association, and checkout
blocking/pausing when the agency has no plans or no connected Stripe account
are all unbuilt.

## View/manage platform integrations (story 13) — 1 spex

`criterion_571` — a broken/expired integration doesn't show an error sync
status.

## Account deletion (story 32) — 1 spex

`criterion_550` — no confirmation email is sent after account deletion.

## Connect marketing platform via OAuth (story 11) — 1 spex

`criterion_76` — an unauthenticated-access edge case on the platform
connection page.

## Things to know before working this suite

- **The suite makes no network calls.** Every cassette surface is
  `mode: :replay`; a dirty `test/cassettes/` after a run means a `:replay`
  was dropped.
- **LazyHTML replaced Floki** and raises rather than failing to match on an
  unquoted attribute value that starts with a digit —
  `[phx-value-id='#{id}']`.
- **`Enum.all?([], _)` is true.** Assert a list is non-empty before asserting
  over it.
- **Application config is global.** The five Google provider test modules and
  `billing_test.exs` are `async: false` for this reason; anything new that
  mutates the same config has to join them.
