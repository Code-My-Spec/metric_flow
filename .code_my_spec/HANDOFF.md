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
| `credo` | **401 issues** (was 775) | 279 are one spex convention; ~122 ordinary |

Started the day at 2175/2931 and 0/374, so the drift is gone; what is left is
feature work plus the credo list.

**Read §1 before trusting the credo row.** Until code_my_spec `866ba007b` the leg
could not write a finding to the server at all, so every number here came from
credo's own output and nothing downstream ever saw one.

## 1. Credo — it crashed, then it could not record

`mix credo` **goes through the harness**; running it is the harness path, not a way
around it.

### The 401 below were never in the database

Measured 2026-09-23 after the crash was fixed: the leg ran, found its issues, and
recorded **zero** of them.

    - credo: failed, 0 problem(s)
        ERROR 22001 (string_data_right_truncation)
        value too long for type character varying(255)

`problems.file_path` on the server was `varchar(255)`. A generated spex filename
is as long as the criterion sentence that named it, and **27 of this project's
374 spex cross 255 — the longest is 304 characters.** The insert is one
transaction on purpose, so a single over-long path discarded the whole source.
The harness said the rest:

> That analyzer ran, but nothing was recorded from it. The run is still open on
> the server, so the next stop will report analysis pending rather than clean.

So this project had **0 problems rows from any leg, ever**. The counts in the
table below are real — they come from credo's own output — but nothing downstream
of the analyzer could see them, and grinding them to zero would not have turned
the leg green. A gate reading problems reads none and concludes clean; a human
reading the leg sees a failure with nothing in it.

Fixed on the platform side in code_my_spec `866ba007b`, which widens
`problems.file_path`, `file_edits.file_path` and `issues.source_path` to `text`,
with a regression test that pushes a 304-char path through `create_problems/2`.
**metric_flow needed no change for this** — the filenames are correct and
load-bearing (`mix spex` globs `_spex.exs`, the scanner keys criteria off
`criterion_*_spex.exs`).

Why it hid: max `file_path` across every other project was 186. This is the first
project whose criteria are written as full sentences. And `files.path` was
already `text`, which is why the 2329-file sync of this same checkout succeeded
while the analyzer on it silently did not — file sync working is **not** evidence
that path length is fine.

### Before that, it could not run at all

It died outright on credo 1.7.16 + Elixir 1.20.2:
`Credo.Code.Token.position/1` has no clause for the 7-element `:sigil` token 1.20
emits, so `Consistency.SpaceAroundOperators` died on a `~w(...)` in
`quick_books.ex` and took the run with it. `{:credo, "~> 1.7"}` already allowed
the fix; only `mix.lock` was pinning it. Updated to **1.7.19** — which also moved
jason 1.4.4 → 1.4.5, carrying a security advisory fix.

Then 775 issues, now **401**:

| count | check | what it is |
|---|---|---|
| ~~374~~ | `WrongTestFilename` | **resolved by config.** A credo 1.7.17+ check flagging any file that `use`s a test case without a `_test.exs` name — every spex, by a name that is not negotiable (`mix spex` globs `_spex.exs`, the scanner keys criteria off `criterion_*_spex.exs`). Disabled in `.credo.exs` with the trade-off written down. |
| 279 | `NoDirectSendInSpex` | **real, and the big one.** `send(context.view.pid, {:sync_completed, ...})` — spex injecting an internal message instead of driving the UI. This is the platform's own convention check (`CMS0001`) and the violations are genuine: each site needs the spex to trigger the real path. Spec-rewriting work, and per house rule not a subagent's job. |
| 33 | `AliasUsage` | ordinary |
| 24 | `MaxLineLength` | ordinary |
| 17 | `BoolOperationOnSameValues` | real but harmless — literal duplicates like `html =~ "clicks" or html =~ "clicks"`, all in spex |
| 12 | `AliasOrder` | ordinary |
| 9 | `Nesting` | ordinary |
| ~28 | the rest | `RedundantBlankLines`, `CyclomaticComplexity`, `StringSigils`, `ExpensiveEmptyEnumCheck`, `FunctionArity`, `CondStatements`, … |

So credo splits into **279 spex-convention violations** and **~122 ordinary
findings**. The 122 are a mechanical afternoon. The 279 overlap heavily with the
spex quality work and should be done with the spex, not separately.

**Gotcha for whoever touches `.credo.exs`:** credo's `checks.enabled` key
*replaces* the default check list rather than merging into it — listing one check
there left exactly one check running out of 69. `checks.disabled` merges.

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

- **`mix credo` and the other analysis tasks route through the harness.** Running them is the harness path; no ceremony needed.
- **A leg reporting `failed, 0 problem(s)` is not a clean leg.** It usually means
  the result was rejected on write, and `Analysis.status` does not say why. Grep
  `~/.codemyspec/web.log` for `22001` or `Reconciler.fail`, and `harness.log` for
  `REJECTED`. That is how the `varchar(255)` path bug in §1 was found, after it
  had been invisible for the whole onboarding.
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
