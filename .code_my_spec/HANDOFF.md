# Handoff — start here

**Goal**: get this app developing inside CodeMySpec. Concretely that means the
harness's analysis goes green, because that is what the requirement graph gates
on. The analyzer runs four legs per working copy — `compile`, `credo`, `exunit`,
`spex` (`CodeMySpec.Analysis`) — and a red leg stops the checks after it.

Read `STATUS.md` for how the project got here and `TEST_FAILURES.md` for the
per-failure inventory. This file is only the current front line.

## The four legs, as of 2026-09-23

| leg | state | what is in the way |
|---|---|---|
| `compile` | green (test env) | — |
| `exunit` | **2904/2917**, 13 failing, 10 excluded | three unbuilt features |
| `spex` | **360/374**, 14 failing | the same three features |
| `credo` | **never measured** | unknown — see below |

Started the day at 2175/2931 and 0/374, so the drift is gone; what is left is
feature work plus one unmeasured leg.

## 1. Credo has not been run — and run it through the harness

I started `mix credo --strict` directly and that was the wrong move: analysis is
the harness's job, it shells into each working copy and builds into that copy's
`_build/analyzer`, and running it by hand competes with its sweeps. Get the number
from an analyzer run on this copy, not from a terminal.

`.credo.exs` exists and `.code_my_spec/credo_checks/` holds custom checks, so this
leg has never been exercised on a suite that only started running today. Expect
findings. Budget for it before assuming the app is close to green.

## 2. The three features that own all 27 remaining failures

None of them exists in `lib`; all three already have acceptance criteria written
as tests and spex, which is why they belong to the agent team as stories rather
than to a repair pass. Criteria and what already exists per feature are in
`TEST_FAILURES.md`.

- **Agency domain-based auto-enrollment** — 9 tests + 6 spex. Schema and
  repository exist (`AutoEnrollmentRule`, unique on `[:agency_id, :email_domain]`);
  the LiveView form does not.
- **Agency white-label** — 7 spex. `WhiteLabelHook` is already in the `/app`
  live_session, so the read path exists; the settings form does not.
- **Visualization preview** — 4 tests. No `preview-chart-btn`, no `preview_chart`
  handler; the module carries unused `fetch_metric_data/2`, `page_title_for/1` and
  `build_template_spec/3` defaults, i.e. an editor someone stopped halfway through.

## 3. The requirement graph needs one read

`requirements` is 0 rows and `graph_invalidations` holds **298 queued** for
working copy `3d7fe72b-0b24-43bc-a0c6-7b9c1bc9d98b`. The rows come from a publish
whose compute is triggered by a read, so the trigger is an agent starting on this
project or its page being opened on dev. Not done here on purpose — starting an
agent is outward-facing. The old project-level cache row puts the graph at ~894
nodes / 1106 edges.

Onboarding itself is complete: `/health` on :4004 lists the checkout
`connected`, `onboarded`, `watching`; 2329 files synced; components 152 → 182;
preview tunnel provisioned.

## 4. Still the user's calls

- **DevOps SSM → sops.** Unchanged and unstarted; needs the AWS credentials.
  Gates promotion and deploy.
- **`cms_new` template fixes**, identified but not made: `.cms_harness.json`
  missing from the generated `.gitignore`; `spex_boundary.ex.eex` deps narrower
  than its own moduledoc claims (any spex doing `use <App>Test.ConnCase` trips a
  forbidden reference); no `Spex.Fixtures` template.

## Landmines, all paid for once already

- **Run analysis through the harness**, not `mix` by hand. See leg 1.
- **The suite makes no network calls now** — every cassette surface is
  `mode: :replay`. If `git status -- test/cassettes/` is ever dirty after a run, a
  `:replay` was dropped. It used to write 714 lines per run and the AI tests were
  failing with "Your credit balance is too low to access the Anthropic API".
- **`Enum.all?([], _)` is true.** Four tests were green on an empty list. Assert
  non-empty before asserting over a list.
- **Application config is global.** The five Google provider modules and
  `billing_test.exs` are `async: false` because they mutate `:google_client_id`,
  `:oauth_providers` or the Logger level. This conflicts with "full async and
  isolation is always preferable" and was a deliberate, argued exception — there is
  no per-test sandbox for application env.
- **`String.to_existing_atom/1` does not raise for the atom you expect.** Atoms
  are never collected. Two places used the raise as control flow; both now match on
  a reason.
- **LazyHTML replaced Floki** and raises on selectors Floki merely failed to
  match — `[phx-value-id=#{id}]` must be quoted.
- **`mix test` needs `MIX_TEST_PARTITION`**; onboarding wrote it into
  `.claude/settings.local.json` (partition `h57a0d9cb`).
