# Metric Flow — status, 2026-09-23

First customer project. Onboarded to dev today; not yet workable by the agent team.

Dev project: `5217fb4a-e2cd-493d-9e5f-2482fb8c4f2c` · repo: `/Volumes/X10 Pro/github/metric_flow` (permanent home)

---

## Where we are in one table

| | state | blocking the agent team? |
|---|---|---|
| Stories / criteria on dev | **53 / 459**, 374 with `spec_path` | no — done |
| Components on dev | 152 | no |
| Working copies | **0** | **yes — hard blocker** |
| Requirement graph | **0 requirements** | **yes — consequence of the above** |
| `mix compile` (test env) | passes | no |
| `mix test` | **2175/2931 pass, 756 fail** | yes, for code work |
| `mix spex` | loads; **0 pass** | yes, for spec work |
| QA | 57 historical dirs (42 complete / 101 failed), **0 qa_attempts on dev** | yes, for QA work |
| DevOps (secrets/deploy) | on AWS SSM, not sops | yes, for promotion/deploy |
| Cassette replay | misses fall through to live calls | no — worth closing, not a blocker |

---

## The headline: none of this code had ever been run

This is the thing to understand before reading the rest. `mix.exs` has:

```elixir
defp elixirc_paths(:test), do: ["lib", "test/support", "test/spex"]
```

That compiles **`.ex` files only**. The tests under `test/` and the 374 `_spex.exs`
files are loaded at runtime, so `mix compile` never looked at any of them. Behind
that gap three plain syntax errors had accumulated, each sufficient on its own to
stop the entire suite:

- `~s(handle_event/3 ("delete"))` — paren-delimited sigils don't nest, so the sigil
  ends at the first `)`. Invalid on 1.19.4 and 1.20.2 alike; **not** a version issue.
- a test *name* interpolating `#{account_id}`, a variable that exists nowhere.
- one `end` too many (12 `do` blocks, 13 `end`s).

Plus every spex called `import_givens`, which no longer exists in the library.

All fixed (`7f41c22`). All 510 `.exs` files under `test/` now parse and both suites
run. The point stands: a green build here has never meant anything, and that is why
the numbers below are as bad as they are.

---

## Tests: 756 failures, essentially one cause

```
Result: 2175/2931 passed
Failed: 756 tests
```

Failure kinds: 369 `Ecto.InvalidChangesetError`, 324 `MatchError`, 63 other.
**1032 log lines mention the same enum**, and 693 of the 756 trace to it:

```elixir
# lib/metric_flow/accounts/account.ex
@account_types [:client, :agency]
```

…while **14 files still create `type: "personal"`**, including the shared fixture
`MetricFlowTest.AiFixtures.create_personal_account!/1` that most of the suite
funnels through.

Commit `7b48ef4` ("Add agency nav, account type enum, and agency clients page")
narrowed the enum and never updated the callers. Because `test/` isn't compiled and
the suite was never run, nothing caught it.

**This is one decision, not 756 bugs.** Someone has to answer: is `:personal` still
a real account type (add it back to the enum) or was it deliberately removed (fix
the 14 call sites)? Answering that likely clears ~690 failures in one pass. The
remaining ~63 are genuine individual failures worth looking at afterwards.

Top failing files: `ai_test.exs` (64), `ai_repository_test.exs` (54),
`accounts_test.exs` (49), `account_repository_test.exs` (45),
`correlations_repository_test.exs` (38).

---

## Spex: all 374 load, none pass

Fixed today: `import_givens X` → `import X` in all 374 files (identical line in every
one, so the substitution was exact).

What remains is a second API drift, and it's the real work:

```
** (ArgumentError) Step "..." must return {:ok, context}. Got: :ok
```

sexy_spex 0.2.1 requires every step block — `given_`, `when_`, `then_`, `and_`, and
registered givens — to return `{:ok, context}`. Bare `:ok` is rejected. **All 374
files contain bare `:ok` step endings: 1478 occurrences.** So every spex fails on its
first such step.

The good news is it's scriptable. Step declarations are overwhelmingly uniform:

| context variable | count |
|---|---|
| `context` | 3022 |
| `_context` | 3 |
| none declared | 1 |

So a transform that walks each bare `:ok`, finds its enclosing step declaration, and
substitutes that step's context variable handles ~99.9% of sites mechanically, with
4 to do by hand. It needs a real verification run afterwards, not just a compile.

Also worth knowing: **one spex filename is long enough that `sed -i` fails on it**
("File name too long" — the temp file exceeds `NAME_MAX`) and takes its whole batch
down silently. Use a tool that rewrites in place. This will bite any future bulk edit.

---

## QA

57 QA directories on disk from previous runs: **42 `result_complete`, 101
`result_failed`, 2 obsolete**. So QA has been exercised historically and mostly
failed.

On dev: **0 `qa_attempts`**. The migration deliberately skips QA attempts (along with
files, problems, components, requirements, analysis runs, file edits) — those are
derived and the harness recomputes them. So QA history lives only in this repo's
`.code_my_spec/qa/` tree, not on the server.

Nothing can be QA'd until there's a working copy and a preview to drive.

---

## DevOps migration — the known piece, and it's blocked on you

metric_flow fetches app secrets from **AWS SSM at container boot** via
`MetricFlow.Secrets.load!/1` (`config/runtime.exs`), with `.kamal/secrets-common`
carrying AWS bootstrap creds plus a registry token. The platform convention is
sops + age.

| | metric_flow today | convention (`cms_new`) |
|---|---|---|
| app secrets | AWS SSM `/metric_flow/<env>/*` | `envs/<env>.enc.env`, sops+age |
| kamal secrets | `.kamal/secrets-common` w/ AWS creds | `.kamal/secrets` w/ `SOPS_AGE_KEY` |
| deploy | `scripts/deploy` sourcing SSM | `bin/deploy` reading the age key |

Present: `Dockerfile`, `.github/workflows/build.yml`, `config/deploy.yml`,
`config/deploy.uat.yml`, `rel/overlays/bin/{migrate,server}`.
Missing: `.sops.yaml`, `.kamal/secrets`, `bin/deploy`, `bin/backup`, `envs/`.

This is the same migration MarketMySpec went through, and it falls under the standing
principle: adapt the legacy app to the platform, not the reverse. **The blocker is the
secret values** — they're in AWS SSM and pulling them needs AWS credentials. A peer
session previously declined to fetch those unilaterally and left it to you; I'm doing
the same. Say go and I'll do it.

---

## Cassette misses fall through to live calls

Running `mix test` appended 714 lines of fresh recordings across 5 cassettes, with
today's `recorded_at`, against `https://api.anthropic.com/v1/messages` (two calls,
`claude-sonnet-4-5`) and `https://api.stripe.com/v1/account_links`. The Stripe entry
came back with a real `request_log_url` carrying an account id and request id, so that
one definitely left the machine.

Proportion, since the first draft of this doc overstated it: the **Stripe key is
sandboxed** — the recorded ids are test mode (`acct_1TIup0…`, `.../test/workbench/...`) —
and two Sonnet calls is pennies, not a cost problem. The Anthropic dependency is also
on its way out, to be replaced with alloy and local Claude Code.

The actual defect is narrower and still worth closing: **a cassette miss falls through
to a live call and records it.** `config/runtime.exs` has a `:test_credentials` block
explicitly labelled "cassette recording credentials", so recording is meant to be a
deliberate act and ordinary runs are meant to replay. Two consequences:

- runs are non-deterministic and depend on network reachability
- a failing run writes new episodes into the cassettes, which is how cassettes get
  corrupted — I reverted today's

Worth a look before the agent team runs the suite on a loop, but it is not the blocker
the first draft made it out to be. Whatever replaces the Anthropic client should replay
by default and require an explicit flag to record.

## Hard blocker for the agent team

```
working copies: 0     requirements: 0
```

No harness has ever registered for metric_flow, so there is no working copy; with no
working copy there is no requirement graph; with no graph there is nothing to hand an
agent. `get_next_requirement` has nothing to answer with.

Fixed today to make this possible: `config.yml` now names the project (`223e4c3`),
and `local_path` points at the real checkout. Onboarding a harness here is the next
concrete step and is not blocked on anything.

---

## What landed today

**metric_flow** (5 commits, none pushed)

| commit | what |
|---|---|
| `6a37f91` | QA + spex dirs renamed numeric → slug (1429 pure renames, verified byte-identical) |
| `223e4c3` | `config.yml` names the project — was falling through to a dead `local_path` |
| `98c1e3e` | path deps → hex; `given/2` → `register_given/3`; generator compat shims |
| `b3ca4cf` | `MetricFlowSpex.Case` + `Fixtures` bridge; removed a duplicate boundary breaking clean builds |
| `7f41c22` | three syntax errors, `import_givens` → `import`, `.tool-versions` |

**code_my_spec** (2 commits) — both were hard blockers on onboarding anything locally

| commit | what |
|---|---|
| `dfe479eb1` | Four CLI migrations carried Postgres-only SQL (`ALTER COLUMN`, `UPDATE…FROM`, `NULLS NOT DISTINCT`). The first raises, so Ecto stopped the set — **every local SQLite DB had been stuck since 2026-08-23**, 16 migrations stranded. Third instance of the shape `cms.guard_cli_migrate` already documents twice. |
| `489814ce3` | Six columns the shared schemas *select* that no CLI migration created, so `Repo.get(Project, id)` couldn't read a project at all. Scope measured across all 69 schemas, not guessed. |

`~/.codemyspec/cli.db` went 128 → 145 migrations. Backups at
`~/.codemyspec/cli.db.bak-20260923-184955` (pre) and `-191645-at144`.

Two incidental notes: the dev account **"Anderson" was flipped free → pro** (the
migration gates on a paid plan — reversible), and **8 orphaned `criteria → stories`
rows** in cli.db predate all of this, which is why 459 of 467 criteria migrated.

---

## What I was doing with the agent team

The governing goal has been: *get a story from product through spec, code, promotion
and QA end to end with no intervention.* **Broken Oaths** was the proving ground, and
it is finished:

```
61 stories · 1474 / 1476 requirements satisfied
```

The only 2 outstanding are `deploy`, which is deliberately outside
`StoryExecution.@completion_names`. Seven stories completed end-to-end in the most
recent stretch (915, 918, 941, 947, 950, 953, 942) — 941 went from parked through
product → spec → code → promote → browser QA with no intervention, which is the
thing we were trying to prove.

Fleet now: Broken Oaths has `coding`, `main` ×2, `product`, `qa` all running and
continuous — **with nothing left to do**. Metric Flow has no agents and no working
copy.

The recurring class of bug worth carrying forward: **"a person answering a gate is
not an edge."** `Work.consider_*` is edge-triggered and nothing polls, so a missed
edge is a permanent stall. Four distinct instances were found and fixed individually
(a restarted agent, a resumed agent, an answered question, a denied tap-out), and
then `Digest.quiet?/1` was fixed as the safety net underneath all of them — it had
been reporting an idle-but-eligible agent as "settled", which is the one state the
cadence exists to catch.

### The goal from here

Point the team at Metric Flow and have a main agent run it under supervision. In
dependency order:

1. **Onboard a harness** → working copy → requirement graph. Nothing else can start.
2. **Answer the `:personal` account-type question** → likely ~690 tests green.
3. **Close the live-API hole** before any agent runs the suite on a loop.
4. **Script the spex `{:ok, context}` migration** → 1478 sites, ~4 by hand, then verify.
5. **DevOps migration off SSM** → needs your AWS call. Gates promotion and deploy.
6. Then set an active story and let the team run it, same as Broken Oaths.

Steps 1–4 are mine and unblocked. Step 5 is yours. Only after 1 does any of the
agent machinery have anything to bite on.
