# Handoff — start here

**Goal**: keep this app developing inside CodeMySpec. The analyzer runs four
legs per working copy — `compile`, `credo`, `exunit`, `spex`
(`CodeMySpec.Analysis`) — and a red leg stops the checks after it.

Read `STATUS.md` for where the project stands and `TEST_FAILURES.md` for the
current per-failure inventory. This file is only the front line.

## The four legs, as of 2026-09-30 (this copy, `three-features`)

| leg | state |
|---|---|
| `compile` | green |
| `credo` | green — 0 issues |
| `exunit` | green — 2919 passed, 10 excluded (`:needs_cassette`), 0 failed |
| `spex` | 27 failing — see `TEST_FAILURES.md` |

All 27 spex failures are gaps in unbuilt or partly-built features (agency
white-label config, agency auto-enrollment, the paywall CTA, a handful of
agency-billing edge cases, one OAuth-connect accessibility gap, one
deletion-confirmation email). None are wiring or drift.

## Open issues that matter right now

Product/code, not framework — `list_issues` has the full set with IDs:

- `f2ff4147` — 178 compiler warnings, ~130 of them Boundary violations in two
  clusters (accepted, not yet scheduled)
- `602c92a3` — `priv/repo/qa_seeds.exs` crashes on `Account.type` enum drift;
  QA Test Account had zero members (accepted)
- `6adf1a68` — story 1094's acceptance criterion embeds a known limitation
  (insert-not-upsert) instead of the intended behavior (accepted)
- `d9bffad1` — story 1093's acceptance criteria embed a known bug and an
  architectural refactor note instead of testable behavior (accepted)
- `5540e192` / `577fd50e` — flaky full-suite spex failures cycling within the
  `ai-chat-for-data-exploration` story, including a Postgrex connection drop
  during promote's spex sweep (accepted, still open)
- `9c015a8c` — `cms_gen.support_widget` output failed `credo --strict`
  (incoming — already fixed here in `60ed026`, awaiting triage/close)

Fifteen more `[low]` findings are real but cosmetic (raw numeric account
names, an unfriendly sync error message, a dead-code event handler, missing
`data-role` attributes, etc.) — see `list_issues` for the full set.

Framework/harness issues (agent tooling, promote-gate behavior, devops_status
UI, and similar) are tracked the same way but are CodeMySpec's own surface,
not metric_flow's — not repeated here.

## What's next

Feature work only: finish the remaining BDD-spec-backed features (agency
white-label, agency auto-enrollment, paywall) story by story, same as any
other requirement. DevOps is on and UAT/prod are deployed — nothing here is
blocked on infrastructure anymore.

## Landmines, still live

- **`mix credo`, `mix test`, `mix spex` route through the harness.** Running
  them is the harness path; no ceremony needed.
- **The suite makes no network calls.** Every cassette surface is
  `mode: :replay`. If `git status -- test/cassettes/` is ever dirty after a
  run, a `:replay` was dropped.
- **`Enum.all?([], _)` is true.** Assert a list is non-empty before asserting
  over it.
- **Application config is global.** The five Google provider test modules and
  `billing_test.exs` are `async: false` because they mutate
  `:google_client_id`, `:oauth_providers` or the Logger level. Anything new
  that does the same has to join them.
- **LazyHTML replaced Floki** and raises on selectors Floki merely failed to
  match — `[phx-value-id=#{id}]` must be quoted.
- **`mix test` needs `MIX_TEST_PARTITION`** — already set per-worktree.
